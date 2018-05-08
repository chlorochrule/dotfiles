# dotfiles
## Dependencies
### Ubuntu
```bash
sudo apt install -y build-essential curl git wget
```
Desktop  
```bash
sudo apt install -y xsel xdotool fcitx fcitx-mozc libxss1 libappindicator1 libindicator7
```
Google Chrome  
```bash
[ -z "${DLHOME}" ] && export DLHOME="${HOME}/Download"
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P "${DLHOME}"
sudo dpkg -i "${DLHOME}/google-chrome*.deb"
rm "${DLHOME}/google-chrome*.deb"
```
Fonts
```bash
bash -c "$(curl -fsSL https://github.com/hbin/top-programming-fonts/raw/master/install.sh)"
```
## Install
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/chlorochrule/dotfiles/master/init/installer.sh)"
```
