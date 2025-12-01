# CUE-HTML Generation Project - 作業計画書

## 1. プロジェクト構造（Tree with 責務）

```
cue-html/
├── flake.nix                    # [責務] Nix開発環境定義（CUE, Go 1.21+, jq, curl）
├── .envrc                       # [責務] direnv設定（自動flake環境読み込み）
│
├── cue.mod/                     # [責務] CUEモジュールルート
│   └── module.cue               # [責務] モジュール名・バージョン定義
│
├── schema/                      # [責務] 型定義とバリデーションルールの集約
│   ├── model.cue                # [責務] #Fragment/#Section/#Page 型定義
│   ├── validation.cue           # [責務] 参照整合性・path重複・H1/level制約
│   └── htmx.cue                 # [責務] htmx関連の型定義（hx-*属性）
│
├── render/                      # [責務] HTML生成ロジック（CUEのみ）
│   ├── print-html.cue           # [責務] Section→HTML変換（h1/h2/h3決定）
│   ├── layout.cue               # [責務] レイアウト分岐（docs/article/lp）
│   ├── common.cue               # [責務] <head>/<footer>等の共通部品
│   └── commands.cue             # [責務] `cue cmd ssg` 定義（export→Go呼び出し）
│
├── content/                     # [責務] 実コンテンツ定義（値）
│   ├── fragments/               # [責務] 再利用フラグメント集
│   │   ├── common.cue           # [責務] 全種別共通フラグメント
│   │   ├── docs.cue             # [責務] docs専用フラグメント
│   │   └── articles.cue         # [責務] articles専用フラグメント
│   │
│   └── pages/                   # [責務] ページ定義（Section組み立て）
│       ├── docs.cue             # [責務] /docs/** ページ定義
│       ├── articles.cue         # [責務] /articles/** ページ定義
│       └── lp.cue               # [責務] /solo/** pSEO LP定義
│
├── cmd/                         # [責務] Go実装プリンタ（極薄）
│   └── html-printer/
│       ├── main.go              # [責務] JSON読み込み→ファイル書き出しのみ
│       └── go.mod               # [責務] Goモジュール定義
│
├── scripts/                     # [責務] シェルスクリプト版（代替実装）
│   └── print-html.sh            # [責務] jqでJSON→HTMLファイル出力
│
├── tests/                       # [責務] テストとDoD検証
│   ├── validation_test.cue      # [責務] CUE vet実行＋制約チェック
│   ├── snapshot_test.sh         # [責務] HTML差分検証
│   ├── htmx_check.sh            # [責務] 全HTMLにhtmx CDN存在確認
│   │
│   └── snapshots/               # [責務] スナップショット格納
│       ├── docs_example.html    # [責務] docs期待値
│       ├── article_example.html # [責務] article期待値
│       └── lp_example.html      # [責務] LP期待値
│
├── out/                         # [責務] 生成HTML出力先（git無視）
│   └── .gitkeep
│
├── .github/                     # [責務] CI/CD自動化
│   └── workflows/
│       └── validate.yml         # [責務] CUE vet, snapshot, htmx check実行
│
├── README.md                    # [責務] プロジェクト概要・使い方
└── PLAN.md                      # [責務] 本ドキュメント（作業計画・DoD）
```

---

## 2. DoD（Definition of Done）詳細化

### 2.1 機能完成の定義

#### 必須機能
- [ ] `cue cmd ssg` で docs/articles/LP の HTML が生成される
- [ ] `/docs/**`, `/articles/**`, `/solo/**` のパスが正しく生成される
- [ ] Fragment の再利用が複数ページで動作する
- [ ] Section の level (1/2/3) が正しく h1/h2/h3 に変換される
- [ ] htmx CDN スクリプトが全ページの `<head>` に含まれる
- [ ] canonical HTML（本文埋め込み済み）が生成される

#### 拡張機能（後回し可）
- [ ] hx-get 属性の動的付与（ログイン後差し替え等）
- [ ] マルチサイト対応（siteId）
- [ ] 差分ビルド（変更ページのみ再生成）

### 2.2 品質基準

#### CUEバリデーション
- [ ] `cue vet ./...` がゼロエラーで通る
- [ ] fragmentId の参照整合性が保証される
- [ ] path の重複チェックが動作する
- [ ] 1ページ1つの H1 制約が検証される
- [ ] level 飛び級（1→3）がエラーになる

#### HTML品質
- [ ] 生成HTMLが W3C Validator でエラーなし（警告は許容）
- [ ] `<!DOCTYPE html>` が全ページに存在
- [ ] `<meta charset="UTF-8">` が含まれる
- [ ] SEOメタ（canonical等）が正しく出力される

### 2.3 テスト基準

#### 自動テスト
- [ ] `tests/validation_test.cue` が全制約を検証
- [ ] `tests/snapshot_test.sh` が3種類のスナップショット比較を実行
- [ ] `tests/htmx_check.sh` が htmx CDN の存在を確認
- [ ] CI で上記3テストが自動実行される

#### 手動確認
- [ ] ローカルで `cue cmd ssg` を実行して out/ にHTMLが生成される
- [ ] 生成HTMLをブラウザで開いて表示確認
- [ ] htmx の動作確認（hx-get 実装後）

### 2.4 ドキュメント基準

- [ ] README.md に以下が記載される
  - プロジェクト目的
  - 環境構築手順（Nix flake）
  - `cue cmd ssg` の実行方法
  - ディレクトリ構造の説明
  - テスト実行方法
- [ ] schema/model.cue に型定義のコメント
- [ ] render/print-html.cue に変換ロジックのコメント

### 2.5 デプロイ準備基準

- [ ] 生成HTMLが R2 / S3 等への配置に適した構造（/path/index.html）
- [ ] CI で main ブランチへのマージ時に自動ビルドが走る
- [ ] flake.nix がCI環境でも再現可能

---

## 3. 作業計画（6 Phase）

### Phase 1: 環境セットアップ（1-2h）

**目的**: Nix + CUE + Go の開発環境を構築

**タスク**:
1. `flake.nix` 作成
   - CUE 0.7.0+
   - Go 1.21+
   - jq, curl, tree
2. `cue.mod/module.cue` 作成
3. `.envrc` 作成（direnv用）
4. `README.md` 初期版作成

**完了条件**:
- `nix develop` で環境に入れる
- `cue version` / `go version` が動作

**想定課題**:
- Nix の flake 構文に慣れていない場合、公式ドキュメント参照が必要

---

### Phase 2: スキーマ定義（2-3h）

**目的**: #Fragment/#Section/#Page 型を定義し、バリデーションルールを実装

**タスク**:
1. `schema/model.cue` 作成
   - `#Fragment` 定義（id, title, bodyHtml）
   - `#Section` 定義（id, level, parentId?, fragmentId）
   - `#Page` 定義（id, kind, path, sections, canonical?）
2. `schema/validation.cue` 作成
   - path 重複チェック
   - fragmentId 参照整合性
   - level 飛び級禁止
   - 1ページ1つの H1
3. `schema/htmx.cue` 作成
   - hx-get, hx-target 等の型定義

**完了条件**:
- `cue vet ./schema` が通る
- 制約違反の例を作ってエラーが出ることを確認

**想定課題**:
- CUE の参照整合性の書き方（`#Page.sections[].fragmentId in #Fragment.id`）

---

### Phase 3: レンダリング実装（3-4h）

**目的**: CUE で Section→HTML 変換ロジックを実装

**タスク**:
1. `render/common.cue` 作成
   - `<head>` 定義（htmx CDN含む）
   - `<footer>` 定義
2. `render/layout.cue` 作成
   - docs/article/lp レイアウト分岐
3. `render/print-html.cue` 作成
   - Section → `<section><h*>title</h*>bodyHtml</section>` 変換
   - Page → sectionsHtml 配列生成
   - renderedPages: [{ path, html }] 構造出力
4. `render/commands.cue` 作成
   - `cue cmd ssg` 定義
   - `cue export -e render.renderedPages > tmp.json`
   - Go or sh プリンタ呼び出し

**完了条件**:
- `cue export -e render.renderedPages` でJSONが出力される
- JSON内の html フィールドに `<!DOCTYPE html>` から始まるHTMLが含まれる

**想定課題**:
- CUE の文字列操作（連結、改行、エスケープ）
- `tool/exec` の使い方

---

### Phase 4: コンテンツ定義（1-2h）

**目的**: サンプルコンテンツを作成し、実際にHTMLを生成

**タスク**:
1. `content/fragments/common.cue` 作成
   - 3つ程度のサンプルフラグメント
2. `content/pages/docs.cue` 作成
   - 1つのdocsページ定義
3. `content/pages/articles.cue` 作成
   - 1つの記事ページ定義
4. `content/pages/lp.cue` 作成
   - 1つのLPページ定義

**完了条件**:
- 3種類のページが renderedPages に含まれる
- path が正しく設定されている

---

### Phase 5: プリンタ実装（1-2h）

**目的**: Go または sh で JSON→HTML ファイル書き出しを実装

**タスク**:
1. **Go版**: `cmd/html-printer/main.go` 作成
   - JSON読み込み
   - `out/{path}/index.html` 書き出し
2. **sh版**: `scripts/print-html.sh` 作成
   - jq で JSON パース
   - mkdir -p + echo でファイル出力

**完了条件**:
- `cue cmd ssg` 実行で `out/docs/.../index.html` が生成される
- ブラウザで開いて表示確認

**想定課題**:
- path の正規化（先頭/末尾スラッシュ）

---

### Phase 6: テストとCI（2-3h）

**目的**: DoD を満たすテストを実装し、CI で自動実行

**タスク**:
1. `tests/validation_test.cue` 作成
   - バリデーション制約の網羅的テスト
2. `tests/snapshot_test.sh` 作成
   - 生成HTMLと snapshots/*.html の diff
3. `tests/htmx_check.sh` 作成
   - `grep -r "htmx.org@2.0.8" out/` でチェック
4. `tests/snapshots/*.html` 作成
   - 期待値を手動で作成
5. `.github/workflows/validate.yml` 作成
   - Nix flake + 3テスト実行

**完了条件**:
- ローカルで全テストが通る
- GitHub Actions で CI が通る

**想定課題**:
- スナップショットの初回作成（自動生成 vs 手動作成）
- CI の Nix キャッシュ設定

---

## 4. 未解決事項（明示的な疑問点）

### 4.1 フラグメント粒度
- **現状**: 1段落単位 vs 1セクション単位が未決定
- **影響**: CUE の見通しと再利用性のバランス
- **決定方法**: Phase 4 でサンプル作成後に判断

### 4.2 pageHtml 連結場所
- **選択肢 A**: CUE内で `strings.Join(sectionsHtml, "\n")`
- **選択肢 B**: Goプリンタで連結
- **推奨**: 選択肢 A（CUE側で完結）
- **理由**: プリンタを「純粋な書き出し器」に保つため

### 4.3 htmx 適用範囲のポリシー
- **現状**: どの部分を hx-get 対象にするかルール未定
- **暫定方針**: Phase 3 では canonical HTML のみ生成、hx-* は Phase 7（将来）で追加
- **決定必要事項**: ログイン後コンテンツの扱い

### 4.4 マルチサイト対応
- **現状**: siteId をどこで持つか未決定
- **選択肢 A**: #Page に siteId フィールド追加
- **選択肢 B**: repoを分ける
- **推奨**: Phase 1-6 では単一サイト前提、マルチサイトは Phase 8（将来）

### 4.5 プリンタの選択（Go vs sh）
- **現状**: 両方実装するか、どちらか1つか
- **推奨**: Phase 5 で Go版のみ実装（将来拡張性を考慮）
- **理由**: minify, 差分出力等の追加が楽

---

## 5. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| CUEの参照整合性実装が複雑 | Phase 2遅延 | 公式ドキュメント・コミュニティ参照 |
| htmx CDN の integrity 値変更 | テスト失敗 | バージョン固定、更新時はテスト修正 |
| CI で Nix が遅い | Phase 6遅延 | Cachix等のキャッシュ導入 |
| スナップショットの管理コスト | Phase 6遅延 | 最小限（3ファイル）に留める |
| Go vs sh の決定に時間がかかる | Phase 5遅延 | Go版を先行実装、sh版は後回し |

---

## 6. マイルストーン

| マイルストーン | 完了条件 | 期日目安 |
|--------------|---------|---------|
| M1: 環境構築完了 | `cue version` 動作 | Day 1 |
| M2: スキーマ完成 | `cue vet ./schema` 成功 | Day 2 |
| M3: HTML生成可能 | `cue cmd ssg` でHTML出力 | Day 3-4 |
| M4: テスト実装完了 | 3種テストがローカルで通る | Day 5 |
| M5: CI稼働 | GitHub Actions が通る | Day 6 |
| M6: DoD完全達成 | 全チェックボックスON | Day 7 |

---

## 7. 次のアクション

**今すぐ始めるべきこと**:
1. この PLAN.md の内容を確認・合意
2. Phase 1（環境セットアップ）の着手
3. 疑問点・修正点があれば明示

**確認したいこと**:
- この構造・責務分担で問題ないか？
- DoD の基準は過不足ないか？
- 未解決事項の優先順位は？
