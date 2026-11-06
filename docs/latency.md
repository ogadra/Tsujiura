# ログの遅延

ポーリングの間隔とタイムアウトを決めるため、名前解決してから関数がログを受け取るまでの時間を測る。

## Route53

Route53のクエリログがLambdaに届くまでの遅延を測る。

### 測るもの

`scripts/measure-route53-latency.sh` は、新しいトークンをRoute53のネームサーバーに直接問い合わせ、そのトークンをDynamoDBから読めるまでの時間を測る。

- Lambdaは受け取った時刻を残さないので、DynamoDBから読めた時刻で代える
    - 値には、Lambdaの処理とDynamoDBへの書き込み、1秒ごとの読み取りの間隔が含まれる
    - ページが結果を読めるまでの時間に近いので、ポーリングの間隔とタイムアウトの判断にはこの値を使える
- 開始と終了の時刻はどちらも手元の時計で取るので、時計のずれは値に影響しない
- 1回目はLambdaのコールドスタートを含むことがあるので、2回目以降と分けて読む

### 手順

`terraform apply` と `just deploy-ingest-route53` のあとに、`nix develop` の中で実行する。AWSの認証情報には、Route53のゾーンの読み取りと、結果のテーブルの `dynamodb:GetItem` の権限が要る。

```sh
export RESULTS_TABLE_NAME=<テーブル名>
export RESULTS_TABLE_REGION=<テーブルのリージョン>
scripts/measure-route53-latency.sh 20 300
```

引数は計測の回数と、1回あたりのタイムアウトの秒数。省略すると20回、300秒になる。1回ずつ順に測り、タブ区切りの結果のあとに、最後の行へ集計を出す。

### 結果

| 項目 | 値 |
|---|---|
| 計測日 | |
| 回数 | |
| タイムアウトの回数 | |
| 1回目(ms) | |
| 最小(ms) | |
| 中央値(ms) | |
| p95(ms) | |
| 最大(ms) | |

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
