# 家計サポート・エージェントチームの雛形

家族の家計を、**役割を分けたAIエージェントのチーム**で整理・集計・ふりかえりするための雛形です。
Claude Code（Anthropic社の製品）で動作します。**本リポジトリは Anthropic社とは関係ありません。**

- 作成：Dice-K-ラボ（GitHub：dice-k-lab8787）
- 版：0.2.0（確認日：2026-11-05。0.2.0 で自動実行のスクリプトを追加）
- ライセンス：MIT（`LICENSE` を参照）

> Claude Code は仕様の変更が速いツールです。動かないところがあれば、公式のドキュメントで最新の書き方を確認してください。

## 何ができるか

フォルダに家計の資料（カードの明細CSV、レシートの文字起こし）を入れて、Claude Code に話しかけると、次のことをチームで分担して行います。

1. **資料の整理**：明細やレシートを読み、店名から分類（食費・日用品など）を付けて、月ごとの台帳にまとめる
2. **集計と目標との比較**：分類ごとに合計し、家族が決めた月の目標と比べる
3. **家族向けの月次レポート**：数字が苦手な家族でも読める、やさしい文章のレポートを書く
4. **ルールと役割の点検**：四半期ごとに、分類のルールや役割分担が今の暮らしに合っているかを見直す

分類が決められない支払いは、勝手に決めずに「**要確認**」として家族に聞きます（聞く数には上限があります）。

### できないこと・しないこと

- **投資の助言はしません。** 記録・集計・見える化だけを行います。株や投資信託などの売買をすすめる機能はありません。
- 銀行やカード会社のサイトに自動でログインする機能はありません。資料は自分でダウンロードしてフォルダに入れます。
- 自動実行（毎月・毎朝の定時実行）は Windows のタスクスケジューラ用だけです（下の「自動実行」）。Mac・Linux 用のスクリプトはありません。

## フォルダ構成

```
.
├── CLAUDE.md                 リーダー（メインのClaude）の進め方と共通ルール
├── .claude/
│   └── agents/               チームのメンバー（サブエージェント）
│       ├── records-clerk.md    資料の整理係
│       ├── budget-analyst.md   家計の集計係
│       ├── report-writer.md    レポート係
│       └── policy-reviewer.md  ルールの点検係
├── scripts/                  自動実行（Windows）
│   ├── run_team.ps1            決まった依頼を claude -p で流す
│   └── register_task.ps1       タスクスケジューラに登録・解除する
├── data/                     家族が決めること・家計のデータ（ここではすべて架空）
│   ├── household.md            家族の構成と、家計の目的
│   ├── budget_policy.md        分類と月の目標、家族が決めたルール
│   ├── category_rules.csv      店名 → 分類 の辞書
│   ├── ledger/                 月ごとの台帳（整理係が作る）
│   └── sources/
│       └── 2026-10/            届いた資料（月ごと）
│           ├── card_statement_dummy.csv
│           └── receipt_notes_dummy.md
└── reports/                  チームが書くレポート（置き場所は reports/README.md）
```

`data/` に入っているのは**すべて架空のダミーデータ**です。家族は「パパ・ママ・子1・子2」の4人、店名もすべて架空です。

## 使い方

### 1. 準備

1. Claude Code を使える状態にします（インストールとログインの方法は公式のドキュメントを見てください）。
2. このリポジトリをダウンロードし、好きな場所に置きます。
3. ターミナルでこのフォルダに移動し、`claude` を起動します。
   - **フォルダの中で起動するのが大事です。** 別のフォルダで起動すると、`.claude/agents/` のメンバーが読み込まれません。

### 2. ダミーデータで試す

起動したら、次のように話しかけてみてください。

```
2026年10月の資料を整理して、月次レポートを作って
```

リーダー（メインのClaude）が、整理係 → 集計係 → レポート係の順に作業を振り、最後に結果と「要確認」の一覧をまとめて返します。
できたファイルは `data/ledger/` と `reports/` に保存されます。

ほかの話しかけ方の例：

- `要確認になった支払いの答えです。サンプル通販の 3,980円 は子1の学用品でした`
- `今月の食費が目標を超えた理由を教えて`
- `四半期の点検をして`

### 3. 自分の家計に置き換える

1. `data/household.md` と `data/budget_policy.md` を、自分の家族に合わせて書き直します。**分類と目標、ルールは家族で話し合って決めてください。**
2. `data/category_rules.csv` に、よく使う店と分類を書き足します。
3. `data/sources/YYYY-MM/` を作り、その月の明細CSVやレシートの文字起こしを入れます。
4. ダミーデータ（`*_dummy.*`）は消してかまいません。

## 自動実行（Windows のタスクスケジューラ）

話しかけなくても、決まった時間にチームが動くようにできます。中身は、Claude Code の公式のヘッドレス実行（`claude -p`）です。

https://code.claude.com/docs/en/headless

### しくみ

- `scripts/run_team.ps1`：雛形のフォルダで `claude -p` を実行し、決まった依頼を流します
  - `-Job Monthly`（標準）：「先月の資料を整理して、月次レポートを作って」
  - `-Job Daily`：「今月の資料で、まだ台帳に入っていないものを整理して」
  - 使えるツールは、ファイルの読み書き（Read・Write・Edit・Glob・Grep）とサブエージェント（Agent）だけです。Bash・PowerShell・WebFetch・WebSearch は使わせません（`--tools`・`--allowedTools`・`--disallowedTools`・`--permission-mode dontAsk`）
  - 結果は `logs/YYYY-MM-DD_HHmm.log` に保存し、終わったら Windows の通知で知らせます（失敗したときも）
  - 同じ期間（毎月なら同じ月、毎朝なら同じ日）にすでに成功していれば、何もせずに終わります
  - `claude` が PATH にないときは、VS Code の拡張機能のフォルダ（`%USERPROFILE%\.vscode\extensions\anthropic.claude-code-*\resources\native-binary\claude.exe`）から、いちばん新しい版を探して使います
- `scripts/register_task.ps1`：タスクスケジューラに登録します
  - 毎月1日 8:00 と、失敗に備えた再実行（標準は1時間後の 9:00）
  - 「スリープを解除して実行する」オン、実行時間の上限30分、予定の時刻に動けなかったら、できるようになりしだい実行

### 使い方

PowerShell を開き、雛形のフォルダで次のように実行します。

```powershell
# まず手で1回動かして、ログと通知を確かめる
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_team.ps1 -Job Monthly -Force

# 毎月1日 8:00（と 9:00 の再実行）に登録する
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_task.ps1

# 毎朝 8:00 にも動かしたいとき
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_task.ps1 -Job Daily

# 時刻と再実行の間隔を変える（例：7:30、30分後に再実行）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_task.ps1 -At 07:30 -RetryAfterMinutes 30
```

登録したタスクは、スタートメニューで「タスク スケジューラ」を開き、「タスク スケジューラ ライブラリ」の `kakei-agent-team Monthly`（`Daily`）で確認できます。

### 解除のしかた

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_task.ps1 -Unregister
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_task.ps1 -Job Daily -Unregister
```

タスク スケジューラの画面で、タスクを右クリックして「削除」しても解除できます。

### 自動実行の注意

- **PC の電源とスリープ**：電源が切れているときは動きません（次に起動したとき、できるようになりしだい動きます）。スリープからの解除には、Windows の電源オプションで「スリープ解除タイマーの許可」が有効になっている必要があります。スリープに入る瞬間と重なると途中で止まることがあるので、再実行のトリガーを入れています
- **ログオンしているときだけ動きます**：パスワードを保存しない設定です。サインアウトしていると動きません（ロック画面の状態なら動きます）
- **使用量**：実行するたびに、Claude Code の使用量（契約しているプランの上限、または API の料金）を使います。毎朝動かす前に、毎月の分だけで様子を見てください
- **ログに家計の数字が残ります**：`logs/` は `.gitignore` に入れてありますが、ログのファイルを GitHub・SNS・チャットなどに貼らないでください
- **知らないフォルダで動かさない**：`claude -p` は、フォルダの `.claude/settings.json` のフックなどを、確認の画面なしで読み込みます（公式：https://code.claude.com/docs/en/headless ）。自分で中身を確かめたこのフォルダだけで使ってください
- 自動実行では家族に質問できないので、要確認は一覧にしてレポートに書くよう依頼しています。答えは、あとで話しかけて伝えてください
- 日本語を含む `.ps1` は **UTF-8（BOM 付き）** で保存しています。編集したら BOM 付きのまま保存してください（Windows PowerShell 5.1 が BOM のない UTF-8 を読み違えて、文字化けして動かなくなるため）

## 注意

- **家族のデータを公開しないでください。** 自分の家計に置き換えたら、そのフォルダを GitHub などに公開しないでください（公開するなら非公開のリポジトリにするか、`data/` と `reports/` を `.gitignore` に入れます）。
- **パスワード、カード番号、口座番号、マイナンバーなどは、どのファイルにも書かないでください。** 明細にカード番号の一部が入っている場合は、取り込む前に消してください。
- 分類や集計は AI が行うため、まちがうことがあります。大事な判断の前には、元の明細と照らしてください。
- 税金・社会保険・補助金などの制度は変わります。チームが説明しても、最後は役所や公式のページで確認してください。
- **サポートはありません。** 不具合の報告（Issue）は歓迎しますが、返信や修正は約束できません。個別の家計の相談も受けていません。

## ライセンス

MIT License。著作者 dice-k-lab（2026）。詳しくは `LICENSE` を見てください。
