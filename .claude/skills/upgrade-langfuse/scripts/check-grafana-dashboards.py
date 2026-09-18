#!/usr/bin/env python3
"""Grafanaの全ダッシュボードのパネルクエリを/api/ds/query経由で実際に実行し、
エラーが出ないか確認する。

langfuse/redis/postgresのバージョンを上げた後、GrafanaダッシュボードのうちClickHouse
(events_core、terraform/local/langfuse_grafana*.tf)に生SQLで依存しているパネルが、
Langfuseのスキーマ変更によって壊れていないかを検証するために使う。
ClickHouseデータソース以外のパネル(Prometheus、TestData等)は対象外。

使い方:
    GRAFANA_PASSWORD=<admin_password> check-grafana-dashboards.py <grafana_url> <admin_user>

パスワードはコマンドライン引数(psで他ユーザーからも見える)ではなく環境変数で渡す。

終了コード:
    0: 対象パネルすべて正常
    1: 1件以上のパネルでエラー
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.request

TARGET_DATASOURCE_TYPE = "grafana-clickhouse-datasource"


def api(base_url, auth_header, path, method="GET", body=None):
    url = f"{base_url}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", auth_header)
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def main():
    password = os.environ.get("GRAFANA_PASSWORD")
    if len(sys.argv) != 3 or not password:
        print(__doc__)
        sys.exit(2)
    base_url, user = sys.argv[1], sys.argv[2]
    auth = "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()

    dashboards = api(base_url, auth, "/api/search?type=dash-db")
    ds_type_cache = {}

    def ds_type(uid):
        if uid not in ds_type_cache:
            ds = api(base_url, auth, f"/api/datasources/uid/{uid}")
            ds_type_cache[uid] = ds.get("type")
        return ds_type_cache[uid]

    checked = 0
    failures = []

    for entry in dashboards:
        uid = entry["uid"]
        detail = api(base_url, auth, f"/api/dashboards/uid/{uid}")
        dash = detail["dashboard"]
        dash_title = dash.get("title", uid)

        for panel in dash.get("panels", []):
            panel_ds = panel.get("datasource") or {}
            for target in panel.get("targets", []):
                target_ds = target.get("datasource") or panel_ds
                ds_uid = target_ds.get("uid")
                if not ds_uid or ds_type(ds_uid) != TARGET_DATASOURCE_TYPE:
                    continue

                checked += 1
                query = dict(target)
                query["datasource"] = target_ds
                body = {"queries": [query], "from": "now-90d", "to": "now"}
                ref_id = target.get("refId", "A")

                try:
                    result = api(base_url, auth, "/api/ds/query", method="POST", body=body)
                except urllib.error.HTTPError as e:
                    failures.append((dash_title, panel.get("title"), e.read().decode()[:300]))
                    continue

                ref_result = result.get("results", {}).get(ref_id, {})
                err = ref_result.get("error") or ref_result.get("errors")
                if err:
                    failures.append((dash_title, panel.get("title"), err))

    print(f"checked {checked} ClickHouse panel query(ies) across {len(dashboards)} dashboard(s)")
    if failures:
        print(f"\n{len(failures)} failure(s):")
        for dash_title, panel_title, err in failures:
            print(f"- [{dash_title}] {panel_title}: {err}")
        sys.exit(1)

    print("all ClickHouse panel queries succeeded")
    sys.exit(0)


if __name__ == "__main__":
    main()
