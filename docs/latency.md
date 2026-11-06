# ログの遅延

ポーリングの間隔とタイムアウトを決めるため、名前解決してから関数がログを受け取るまでの時間を測る。

## Cloud DNS

Cloud DNSのクエリログがCloud Run functionsに届くまでの遅延を測る。

### 手順

`scripts/measure-cloud-dns-latency.sh` は、トークンの名前をCloud DNSのネームサーバーへ直接問い合わせ、取り込み関数が書いたFirestoreのドキュメントの `createTime` と送信時刻の差を出す。

1. Terraformのapplyと `just deploy-ingest-cloud-dns` を済ませる
2. `gcloud auth login` で、Firestoreを読める権限のあるアカウントにログインする
3. `timedatectl` で手元の時計が同期していることを確かめる
4. `GOOGLE_CLOUD_PROJECT` を設定し、Cloud DNSのネームサーバーを1本指定して実行する

```sh
scripts/measure-cloud-dns-latency.sh ns-cloud-x1.googledomains.com 10
```

- 第2引数は計測回数で、省略すると10回測る
- 5分待ってもドキュメントができなければ `timeout` と出して次へ進む
- 関数がしばらく動いていないと、最初の1回にコールドスタートの時間が含まれる。ページのポーリングも同じ状況を受けるので、外れ値として除かない

### 結果

| 計測日 | 回数 | timeouts | min (ms) | median (ms) | max (ms) |
|---|---|---|---|---|---|
| | | | | | |
