# CUE-HTML Generation Project - 作業計画書 v2

> **注意**: このドキュメントは実装フェーズの計画書です。実装完了後は削除予定です。

## レビュー反映内容（v1 → v2）

以下の8点を修正しました：
1. ✅ W3C Validator を自動DoDから外し、手動確認に変更
2. ✅ `schema/htmx.cue` をPhase 2から外し、v1ではstubのみ（Phase 7に移動）
3. ✅ sitemap/robots/llms.txt の扱いを明示（v1では範囲外）
4. ✅ `tests/validation_test.cue` の役割を明確化（異常系テストの明示）
5. ✅ sh版をオプション扱いに（Go版のみをDoDに含める）
6. ✅ `render/commands.cue` の責務を整理（export までに留め、実行は別レイヤー）
7. ✅ htmx テストをバージョン非依存に（`htmx.org` のみgrep）
8. ✅ Phase 3と5の完了条件を明確化（JSON確認 vs ファイル出力）

---

## 1. プロジェクト構造（Tree with 責務）

```
cue-html/
├── flake.nix                    # [責務] Nix開発環境定義（CUE, Go 1.21+）
├── .envrc                       # [責務] direnv設定（自動flake環境読み込み）
├── Makefile                     # [責務] タスク実行（ssg: export + printer呼び出し）
│
├── cue.mod/                     # [責務] CUEモジュールルート
│   └── module.cue               # [責務] モジュール名・バージョン定義
│
├── schema/                      # [責務] 型定義とバリデーションルールの集約
│   ├── model.cue                # [責務] #Fragment/#Section/#Page 型定義
│   └── validation.cue           # [責務] 参照整合性・path重複・H1/level制約
│
├── render/                      # [責務] HTML生成ロジック（CUEのみ）
│   ├── print-html.cue           # [責務] Section→HTML変換（h1/h2/h3決定）
│   ├── layout.cue               # [責務] レイアウト分岐（docs/article/lp）
│   ├── common.cue               # [責務] <head>/<footer>等の共通部品
│   └── export.cue               # [責務] renderedPages 構造の定義・export
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
├── tests/                       # [責務] テストとDoD検証
│   ├── validation_test.cue      # [責務] 異常系データで制約エラー確認
│   ├── snapshot_test.sh         # [責務] HTML差分検証
│   ├── htmx_check.sh            # [責務] 全HTMLにhtmx CDN存在確認
│   │
│   └── snapshots/               # [責務] スナップショット格納
│       ├── docs_example.html    # [責務] docs期待値
│       ├── article_example.html # [責務] article期待値
│       └── lp_example.html      # [責務] LP期待値
│
├── tmp/                         # [責務] 一時ファイル（git無視）
│   └── .gitkeep
│
├── out/                         # [責務] 生成HTML出力先（git無視）
│   └── .gitkeep
│
├── .github/                     # [責務] CI/CD自動化
│   └── workflows/
│       └── validate.yml         # [責務] CUE vet, snapshot, htmx check実行
│
└── README.md                    # [責務] プロジェクト概要・使い方
```

**削除項目**（v1から変更）:
- ❌ `schema/htmx.cue` - v1では不要（Phase 7で追加予定）
- ❌ `render/commands.cue` - Makefile に統合
- ❌ `scripts/print-html.sh` - Go版のみに集中

---

## 2. DoD（Definition of Done）詳細化

### 2.1 機能完成の定義

#### 必須機能（v1）
- [ ] `make ssg` で docs/articles/LP の HTML が生成される
- [ ] `/docs/**`, `/articles/**`, `/solo/**` のパスが正しく生成される
- [ ] Fragment の再利用が複数ページで動作する
- [ ] Section の level (1/2/3) が正しく h1/h2/h3 に変換される
- [ ] htmx CDN スクリプトが全ページの `<head>` に含まれる
- [ ] canonical HTML（本文埋め込み済み）が生成される
- [ ] **Go版プリンタが動作する**（sh版は実装しない）

#### 明示的な範囲外（v1では実装しない）
- ❌ hx-get 属性の動的付与 → Phase 7（将来）
- ❌ sitemap.xml / robots.txt / llms.txt 生成 → 別プロジェクト or Phase 8
- ❌ マルチサイト対応（siteId） → Phase 9（将来）
- ❌ 差分ビルド → パフォーマンス問題が出たら検討
- ❌ HTML minify → 必要になったら追加

### 2.2 品質基準

#### CUEバリデーション
- [ ] `cue vet ./...` がゼロエラーで通る
- [ ] fragmentId の参照整合性が保証される
- [ ] path の重複チェックが動作する
- [ ] 1ページ1つの H1 制約が検証される
- [ ] level 飛び級（1→3）がエラーになる

#### HTML品質
- [ ] `<!DOCTYPE html>` が全ページに存在
- [ ] `<meta charset="UTF-8">` が含まれる
- [ ] SEOメタ（canonical等）が正しく出力される
- [ ] 基本的なHTML構造が正しい（開始・終了タグの対応等）

**注意**: W3C Validator によるバリデーションは**手動確認**とします。
- v1では自動チェックを含めません（vnu.jar 等のツール導入コストを避けるため）
- 重要ページは手動で https://validator.w3.org/ にて確認

### 2.3 テスト基準

#### 自動テスト
- [ ] `tests/validation_test.cue` が全制約を検証
  - **役割明確化**: わざと制約違反データを作成し、`cue vet` がエラーを出すことを確認
  - 正常系: `schema/validation.cue` の制約定義
  - 異常系: `tests/validation_test.cue` でエラー発火テスト
- [ ] `tests/snapshot_test.sh` が3種類のスナップショット比較を実行
- [ ] `tests/htmx_check.sh` が htmx CDN の存在を確認
  - **バージョン非依存**: `grep -r "htmx.org" out/` でチェック（バージョン番号は見ない）
  - htmx のバージョンアップ時にテストが壊れないようにする
- [ ] CI で上記3テストが自動実行される

#### 手動確認
- [ ] ローカルで `make ssg` を実行して out/ にHTMLが生成される
- [ ] 生成HTMLをブラウザで開いて表示確認
- [ ] 代表的な3ページを W3C Validator で手動確認

### 2.4 ドキュメント基準

- [ ] README.md に以下が記載される
  - プロジェクト目的
  - 環境構築手順（Nix flake）
  - `make ssg` の実行方法
  - ディレクトリ構造の説明
  - テスト実行方法
  - 将来拡張の方針（htmx動的差し替え、sitemap生成等）
- [ ] schema/model.cue に型定義のコメント
- [ ] render/print-html.cue に変換ロジックのコメント

### 2.5 デプロイ準備基準

- [ ] 生成HTMLが R2 / S3 等への配置に適した構造（/path/index.html）
- [ ] CI でブランチへのpush時に自動ビルドが走る
- [ ] flake.nix がCI環境でも再現可能

---

## 3. 作業計画（6 Phase）

### Phase 1: 環境セットアップ（1-2h）

**目的**: Nix + CUE + Go の開発環境を構築

**タスク**:
1. `flake.nix` 作成
   - CUE 0.7.0+
   - Go 1.21+
   - tree（開発用）
2. `cue.mod/module.cue` 作成
3. `.envrc` 作成（direnv用）
4. `Makefile` 作成（ssg ターゲット）
5. `README.md` 初期版作成

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

**削除項目**（v1→v2 変更）:
- ❌ `schema/htmx.cue` は**作成しない**
  - v1では htmx CDN の `<script>` タグを `render/common.cue` に直接埋め込むだけ
  - hx-get 等の動的属性は Phase 7（将来）で実装時に追加

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
   - `<head>` 定義（htmx CDN `<script>` タグを直接埋め込み）
   - `<footer>` 定義
2. `render/layout.cue` 作成
   - docs/article/lp レイアウト分岐
3. `render/print-html.cue` 作成
   - Section → `<section><h*>title</h*>bodyHtml</section>` 変換
   - Page → sectionsHtml 配列生成
   - CUE内で `strings.Join(sectionsHtml, "\n")` して pageHtml を構成
4. `render/export.cue` 作成
   - renderedPages: [{ path, html }] 構造を定義
   - export 可能な形に整形

**責務の明確化**（v1→v2 変更）:
- `render/export.cue` は**JSON構造の定義のみ**
- 実際の `cue export` コマンド実行は Makefile が担当
- `tool/exec` は使わない（シンプルにする）

**完了条件**（v1→v2 明確化）:
- `cue export -e render.renderedPages` で JSON が出力される
- JSON内の `html` フィールドに `<!DOCTYPE html>` から始まる完全なHTMLが含まれる
- **この段階ではファイル出力はしない**（JSON確認のみ）

**想定課題**:
- CUE の文字列操作（連結、改行、エスケープ）

---

### Phase 4: コンテンツ定義（1-2h）

**目的**: サンプルコンテンツを作成し、JSON出力を確認

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
- `cue export -e render.renderedPages | jq` で構造確認

**フラグメント粒度の決定**:
- この Phase でサンプル実装しながら、「1段落」vs「1セクション」のどちらが使いやすいか判断

---

### Phase 5: プリンタ実装（1-2h）

**目的**: Go で JSON→HTML ファイル書き出しを実装

**タスク**（v1→v2 変更）:
1. **Go版のみ**: `cmd/html-printer/main.go` 作成
   - JSON読み込み
   - `out/{path}/index.html` 書き出し
   - パス正規化（`filepath.Clean` で path traversal 対策）
2. `Makefile` の `ssg` ターゲット実装
   ```makefile
   ssg:
       cue export -e render.renderedPages > tmp/renderedPages.json
       go run ./cmd/html-printer tmp/renderedPages.json ./out
       rm tmp/renderedPages.json
   ```

**削除項目**:
- ❌ sh版（`scripts/print-html.sh`）は**実装しない**
  - 将来の拡張性を考えてGo版に集中
  - 必要になったら後で追加可能

**完了条件**（v1→v2 明確化）:
- `make ssg` 実行で `out/docs/.../index.html` が生成される
- **ブラウザで開いて表示確認**（この Phase で初めて実ファイル出力）
- 3種類のページ（docs/article/lp）が正しく生成される

**想定課題**:
- path の正規化（先頭/末尾スラッシュ、`..` の処理）

---

### Phase 6: テストとCI（2-3h）

**目的**: DoD を満たすテストを実装し、CI で自動実行

**タスク**:
1. `tests/validation_test.cue` 作成（v1→v2 明確化）
   - **異常系テスト**: わざと制約違反のデータを作成
   - 例: path重複、fragmentId不在、level飛び級、複数H1
   - `cue vet` を実行して「エラーが出ること」を確認
2. `tests/snapshot_test.sh` 作成
   - 生成HTMLと snapshots/*.html の diff
3. `tests/htmx_check.sh` 作成（v1→v2 変更）
   - `grep -r "htmx.org" out/` でチェック（バージョン非依存）
4. `tests/snapshots/*.html` 作成
   - Phase 5 で生成されたHTMLを元に期待値を作成
5. `.github/workflows/validate.yml` 作成
   - Nix flake 環境で 3テスト実行

**完了条件**:
- ローカルで全テストが通る
- GitHub Actions で CI が通る

**想定課題**:
- スナップショットの初回作成（Phase 5の出力をそのまま使うか、手動調整するか）
- CI の Nix キャッシュ設定

---

## 4. 未解決事項（明示的な疑問点）

### 4.1 フラグメント粒度
- **現状**: 1段落単位 vs 1セクション単位が未決定
- **影響**: CUE の見通しと再利用性のバランス
- **決定方法**: Phase 4 でサンプル作成後に判断

### 4.2 pageHtml 連結場所
- **決定済み**: CUE内で `strings.Join(sectionsHtml, "\n")` して pageHtml 生成
- **理由**: プリンタを「純粋な書き出し器」に保つため

### 4.3 htmx 適用範囲のポリシー
- **v1方針**: htmx CDN `<script>` タグを `<head>` に入れるのみ
- **Phase 7（将来）**: hx-get 等の動的属性を追加
- **Phase 7 で決定すべきこと**: どのセクションを動的差し替え対象にするか

### 4.4 sitemap/robots/llms.txt の扱い
- **v1方針**: **実装しない**（明示的に範囲外）
- **Phase 8（将来）**: 別プロジェクトとして切り出すか、このrepoに追加するか検討
- **理由**: v1は「HTMLのみ」にフォーカスしてスコープを絞る

### 4.5 マルチサイト対応
- **v1方針**: 単一サイト前提（siteId なし）
- **Phase 9（将来）**: siteId を #Page に追加するか、repo を分けるか検討

---

## 5. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| CUEの参照整合性実装が複雑 | Phase 2遅延 | 公式ドキュメント・コミュニティ参照 |
| CUEの文字列操作が冗長 | Phase 3遅延 | 段階的に実装、必要なら補助関数作成 |
| CI で Nix が遅い | Phase 6遅延 | Cachix等のキャッシュ導入 |
| スナップショットの管理コスト | Phase 6遅延 | 最小限（3ファイル）に留める |
| Go プリンタのpath処理バグ | Phase 5遅延 | filepath.Clean + ユニットテスト |

---

## 6. マイルストーン

| マイルストーン | 完了条件 | 期日目安 |
|--------------|---------|---------|
| M1: 環境構築完了 | `cue version` 動作、Makefile作成 | Day 1 |
| M2: スキーマ完成 | `cue vet ./schema` 成功 | Day 2 |
| M3: JSON生成可能 | `cue export` でJSONが正しく出る | Day 3 |
| M4: HTML出力可能 | `make ssg` でHTMLファイル生成 | Day 4 |
| M5: テスト実装完了 | 3種テストがローカルで通る | Day 5 |
| M6: CI稼働 | GitHub Actions が通る | Day 6 |
| M7: DoD完全達成 | 全チェックボックスON、手動確認完了 | Day 7 |

---

## 7. 次のアクション

### 実装開始前の最終確認
- [ ] この v2 計画書の内容に合意
- [ ] 未解決事項の優先順位を確認
- [ ] Phase 1 から順次着手

### Phase 1 開始準備
- `flake.nix` 作成
- `cue.mod/module.cue` 作成
- `.envrc` 作成
- `Makefile` 作成（ssg ターゲット）
- `README.md` 初期版作成
- `.gitignore` 作成（tmp/, out/ を無視）

---

## 付録: v1からの主要変更点まとめ

| 項目 | v1 | v2（修正後） |
|------|----|-----------
| W3C Validator | 自動チェック | 手動確認のみ |
| schema/htmx.cue | Phase 2で作成 | v1では作成しない（Phase 7へ） |
| sitemap等 | 曖昧 | 明示的に範囲外 |
| validation_test.cue | 曖昧 | 異常系テストと明記 |
| プリンタ | Go + sh 両方 | Go版のみ |
| commands.cue | tool/exec使用 | Makefileに統合 |
| htmx テスト | バージョン固定 | バージョン非依存 |
| Phase 3完了条件 | 曖昧 | JSON確認のみ |
| Phase 5完了条件 | 曖昧 | ファイル出力+ブラウザ確認 |

この v2 計画書で実装を進めることで、v1の曖昧さ・過剰設計を排除し、
「CUE主導のHTML生成エンジン v1」として十分に実装可能な設計になりました。
