# ja-vpngate-proxy

[VPNGate](http://www.vpngate.net/api/iphone/)から日本のVPNサーバだけを抽出し、通信速度が`MIN_SPEED`(デフォルト200Mbps)以上のサーバの中からスコアが高い順に接続します  
ブラウザのプロキシ設定でlocalhost:8118を設定することで使用できます

> 接続できなかった場合は次にスコアの高いサーバへ順番にフォールバックします

> 条件を満たすサーバが1台も無かった場合は、60秒待ってからサーバ一覧を取得し直します

> また、日本サーバであってもpublic-vpn-から始まるVPN(219.100.37.0/24)は同じ場所からのアクセスになってしまうため除外しました

> OpenVPNのTCP/UDPはVPNGateが各サーバの設定ファイル(`OpenVPN_ConfigData_Base64`)に埋め込んだ`proto`行で決まり、**サーバごとに異なります**  
> `PROTO`で絞り込めますが、`proto`はCSVの列ではなく設定ファイルの中にしか無いため、デコードしてから判定しています

# 起動

## docker compose

```bash
docker compose up -d
```

停止する場合は以下を実行してください

```bash
docker compose down
```

イメージは GitHub Actions が main への push ごとにビルドして
[GHCR](https://github.com/BroccoliGG/ja-vpngate-proxy/pkgs/container/ja-vpngate-proxy) に公開しています(linux/amd64 と linux/arm64)

リポジトリ内では `docker-compose.override.yml` が自動で読み込まれ、GHCRのイメージではなく
手元のソースからのビルドに切り替わります。変更を反映するには `--build` を付けてください

```bash
docker compose up -d --build
```

ホスト側のポートは環境変数 `PROXY_PORT` で変更できます(デフォルトは8118)

```bash
PROXY_PORT=18118 docker compose up -d
```

接続対象とする速度の下限は環境変数 `MIN_SPEED` で変更できます(bps単位、デフォルトは200000000 = 200Mbps)  
条件が厳しすぎて接続先が見つからない場合は下げてください

```bash
MIN_SPEED=100000000 docker compose up -d
```

使用するプロトコルは環境変数 `PROTO` で `udp` / `tcp` / `any` から選べます(デフォルトは`any`)

```bash
PROTO=udp MIN_SPEED=50000000 docker compose up -d
```

> **注意**: VPNGateの日本サーバはTCPが大半で、UDPは全体の2割程度しかありません  
> `PROTO=udp` と高い `MIN_SPEED` を同時に指定すると該当0台になりやすく、その場合は60秒待機を繰り返して接続できません  
> `docker compose logs` に `no server matched (...)` が繰り返し出ていたら条件を緩めてください

## サーバで動かす(docker-compose.yml だけを配置する)

`docker-compose.yml` には `build:` を書いていないため、**このファイル1枚をサーバに置くだけ**で動きます
(`Dockerfile` や `start.sh` を持っていく必要はありません)

```bash
curl -O https://raw.githubusercontent.com/BroccoliGG/ja-vpngate-proxy/main/docker-compose.yml
PROTO=udp MIN_SPEED=50000000 docker compose up -d
```

`IMAGE_TAG` でイメージのタグを固定できます(デフォルトは`latest`)

```bash
IMAGE_TAG=sha-1234567 docker compose up -d
```

> **事前準備**: GHCRのパッケージは初回publish時は**private**です  
> 認証なしで`pull`できるようにするには、リポジトリの Packages ページから
> Package settings → Change visibility → Public に変更してください  
> privateのまま使う場合はサーバ側で `docker login ghcr.io` が必要です

> **⚠ セキュリティ**: `ports` の指定は `0.0.0.0`(全インターフェース)に公開されます  
> グローバルIPを持つサーバでそのまま起動すると**誰でも使えるオープンプロキシ**になります  
> 外部に晒したくない場合は `docker-compose.yml` の `ports` を `"127.0.0.1:8118:8118"` に変更するか、
> ファイアウォールで8118番を塞いでください
> (DockerはiptablesをUFWより手前で操作するため、`ufw deny 8118` が効かないことがあります)

## docker run

```bash
docker run --rm -it \
--cap-add=NET_ADMIN --device=/dev/net/tun \
--dns=1.1.1.1 --dns=8.8.8.8 --dns=9.9.9.9 \
-p 8118:8118 \
ghcr.io/broccoligg/ja-vpngate-proxy
```

# 起動確認

proxy指定有り無しでcurlしてグローバルIPが異なっていれば成功です

```bash
$ curl inet-ip.info
$ curl inet-ip.info -x http://localhost:8118
```