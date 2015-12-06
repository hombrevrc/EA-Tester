#!/usr/bin/env bash
CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
. $CWD/.configrc

# Check dependencies.
set -e
type git wget zip unzip pv
[ $# -ne 3 ] && { echo "Usage: $0 [currency] [year] [DS/MQ/T1/T2/T3/T4/RND]"; exit 1; }
symbol=$1
year=$2
bt_src=$3

bt_url=$(printf "https://github.com/FX31337/FX-BT-Data-%s-%s/archive/%s-%d.zip" $symbol $bt_src $symbol $year)
dest="$TERMINAL_DIR/history/downloads"
bt_csv="$dest/$bt_src-$symbol-$year"
scripts="https://github.com/FX31337/FX-BT-Scripts.git"
test ! -d "$dest/scripts" && git clone "$scripts" "$dest/scripts" # Download scripts.
mkdir -v "$bt_csv" || true

echo "Getting data..." >&2
case $bt_src in

  "DS")
    test -s "$dest/$symbol-$year.zip" || wget -cNP "$bt_csv" "$bt_url"  # Download backtest data files.
    find "$dest" -name "*.zip" -execdir unzip -qn {} ';' # Extract the backtest data.
  ;;
  "T1")
    "$dest/scripts/gen_bt_data.py" -o "$bt_csv/$year.csv" -p none "$year.01.01" "$year.12.30" 1.0 4.0
  ;;
  "T2")
    "$dest/scripts/gen_bt_data.py" -o "$bt_csv/$year.csv" -p wave "$year.01.01" "$year.12.30" 1.0 4.0
  ;;
  "T3")
    "$dest/scripts/gen_bt_data.py" -o "$bt_csv/$year.csv" -p curve "$year.01.01" "$year.12.30" 1.0 4.0
  ;;
  "T4")
    "$dest/scripts/gen_bt_data.py" -o "$bt_csv/$year.csv" -p zigzag "$year.01.01" "$year.12.30" 1.0 4.0
  ;;
  "RND")
    "$dest/scripts/gen_bt_data.py" -o "$bt_csv/$year.csv" -p random "$year.01.01" "$year.12.30" 1.0 4.0
  ;;
  *)
    echo "ERROR: Unknown backtest data type: $bt_src" >&2
    exit 1
esac

du -hs "$bt_csv" || { echo "ERROR: Missing backtest data."; exit 1; }

echo "Converting data..."
find "$bt_csv" -name "*.csv" -exec cat {} ';' |
  pv -c -Bk -N "Converting data" -s $(du -sk "$bt_csv" | cut -f1) |
  "$dest/scripts/convert_csv_to_mt.py" -v -i /dev/stdin -f fxt4 -s $symbol -t M1 -p 10 -S default -d "$TERMINAL_DIR/tester/history"
find "$bt_csv" -name "*.csv" -exec cat {} ';' |
  pv -c -Bk -N "Converting data" -s $(du -sk "$bt_csv" | cut -f1) |
  "$dest/scripts/convert_csv_to_mt.py" -v -i /dev/stdin -f hst4 -s $symbol -t M1 -p 10 -S default -d "$TERMINAL_DIR/history/default"

# Make the backtest files read-only.
find "$TERMINAL_DIR" '(' -name '*.fxt' -or -name '*.hst' ')' -exec chmod -v 444 {} ';'

# Add files to the git repository.
#if test -d "$DIR/.git"; then
#  git --git-dir=$DIR/.git add -A
#  git --git-dir=$DIR/.git commit -m"$0: Downloaded backtest files." -a
#fi

echo "$0 done."
