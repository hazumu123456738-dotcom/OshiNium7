---
description: 現在のブランチの変更を、TEMP DEBUG確認→ビルド確認→軽量QAチェック→コミットの順で仕上げる
---

現在のブランチの変更を、mainへ統合できる状態まで仕上げてください。以下の順で必ず実施すること。

1. `git status`と`git diff`で現在の変更点を把握する。
2. `grep -rn "TEMP DEBUG" --include="*.swift" .`を実行し、検証用の一時コードが残っていないか確認する。見つかった場合はすべて削除する。
3. CLAUDE.mdのSkillルーティング表を参照し、今回の変更内容に応じて該当するQA Skill(UI変更を含む場合は`design-review`、まとまった単位の場合は`release-check`、実機確認が必要な場合は`verify`)を実行する。Firestore/Storageルールを変更している場合は`firebase-guardian`も必ず通す。
4. `xcodebuild -project OshiNium7.xcodeproj -scheme OshiNium7 -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/oshinium_build_check build`でビルドが通ることを確認する。
5. 問題が無ければ、変更内容を要約した適切なコミットメッセージを日本語で作成し、ユーザーに確認の上コミットする(git commit実行時はTEMP DEBUG防止Hookが自動でチェックする)。
6. 現在のブランチが`feature/*`の場合は、mainへのマージ方法(マージ or 統合)をユーザーに確認してから進める。`main`上での軽微な作業であればそのままで良い。

途中でTEMP DEBUGが見つかった、ビルドが失敗した、QA Skillで重大な指摘が出た、などの場合は、そこで止めて修正してから最初からやり直す。中途半端な状態で「完了」と報告しない。
