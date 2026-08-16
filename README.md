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

ソースからイメージをビルドして起動する場合は `--build` を付けてください

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

## docker run

```bash
docker run --rm -it \
--cap-add=NET_ADMIN --device=/dev/net/tun \
--dns=1.1.1.1 --dns=8.8.8.8 --dns=9.9.9.9 \
-p 8118:8118 \
tantantanuki/ja-vpngate-proxy
```

# 起動確認

proxy指定有り無しでcurlしてグローバルIPが異なっていれば成功です

```bash
$ curl inet-ip.info
$ curl inet-ip.info -x http://localhost:8118
```