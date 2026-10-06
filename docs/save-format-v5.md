# 저장 형식 v5 전환 기록 (마이팜 2.0)

마이팜 2.0은 농장 관리 앱(1.x, 저장 형식 v1~v4)을 방치형 농장 게임으로 바꾼다. 관리 기록(작물·가축·장부·재고)은
게임 수치(코인·레벨·작물 단계)로 옮길 의미 있는 방법이 없어, **변환하지 않고 원본을 그대로 보관한 뒤 새 게임을 시작**한다.
AGENTS.md §11 형식으로 남긴다. 결정 배경은 `docs/idle-game-plan.md`(D2·D6), 수치는 `docs/game-design.md`.

```text
변경 전 구조:
  SharedPreferences 'farm_state_v1' = 관리 앱 상태 JSON (schemaVersion 1~4, profile·fields·animals·ledger·inventory 등)
  같은 접두사의 '_meta_<키>' = 기기별 값(언어·마지막 백업·업데이트·알림 설정), '_<라벨>_<시각>' = 보관본(최근 5개)

변경 후 구조:
  'farm_state_v1' = 게임 상태 JSON (schemaVersion 5: farmName, simTime(UTC ISO-8601), coins, xp, barn, feedUnits,
                    water, unlocked, fields, animals, breedProgress, nextAnimalId, log)
  'farm_state_v1_meta_management_archive' = 처음 발견한 관리 앱 상태 JSON 원문(손대지 않음, 보관본 개수 제한 밖)

마이그레이션 방법 (GameStore.load):
  1. 저장본이 v5면 그대로 읽는다.
  2. v1~v4면 원문을 management_archive에 그대로 적고(이미 있으면 덮어쓰지 않고 'management_again' 보관본으로),
     profile.name만 이어받아 새 게임을 만든다. 첫 화면에 보관 안내 배너를 띄운다.
  3. 시각(simTime, 기록 시각)은 UTC로 적고 현지 시각으로 읽는다. 시간대 없는 문자열(개발판 저장본)도 현지 시각으로 읽는다.

실패 시 동작:
  - JSON이 깨졌으면 원문을 'corrupt' 보관본으로 남기고 새 게임으로 시작한다(배너 안내).
  - 더 새로운 형식(앱을 낮춘 경우)이면 원문을 'newer_v<N>' 보관본으로 남기고 새 게임으로 시작한다.
  - 저장 실패는 화면 배너로 알리고 다음 저장 때 다시 시도한다.

롤백 가능 여부:
  - 관리 기록 원문은 management_archive에 남는다. 2.0 설정 화면의 '관리 앱 기록 내보내기'(2·3단계 화면 작업에서 추가)가
    이를 1.x 백업 파일 형식('my-farm-backup' 껍데기 + 원문 상태)으로 내보내고, 1.7.x 앱의 복원으로 되살릴 수 있다.
  - 2.0 → 1.7로 앱을 낮추면 1.7은 v5를 읽지 못해 보관본으로 돌리고 예시 농장을 만든다. 이때도 management_archive는
    남아 있고, 다시 2.0으로 올렸을 때 1.7이 만든 예시 기록이 원본을 덮어쓰지 않는다.
  - 앱을 지우면(또는 앱 데이터 삭제) 원문도 사라진다. 2.0으로 올리기 전에 1.x에서 백업 파일을 내보내 두도록
    릴리스 노트에 안내한다.

검증 방법:
  - test/game_store_test.dart: v4 원문 보관·농장 이름 이어받기, 다시 들어온 관리 기록이 원본을 덮어쓰지 않음,
    깨진/더 새로운 저장본 보관, UTC 저장과 시간대 없는 저장본 읽기.
  - 에뮬레이터: 1.5.0·1.7.1 데이터가 있는 상태에서 2.0 개발판으로 덮어 설치해 배너·농장 이름 이어받기 확인.
```
