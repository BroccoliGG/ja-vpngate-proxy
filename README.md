# ja-vpngate-proxy

[VPNGate](http://www.vpngate.net/api/iphone/)から日本のVPNサーバだけを抽出してランダムに接続します  
ブラウザのプロキシ設定でlocalhost:8118を設定することで使用できます

> また、日本サーバであってもpublic-vpn-から始まるVPN(219.100.37.0/24)は同じ場所からのアクセスになってしまうため除外しました

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