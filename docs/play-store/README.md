# Google Play 등록 키트

마이팜은 GitHub 릴리스로 배포하지만, **Android developer verification**(2026년 9월부터 인증된 Android 기기에 설치하려면 앱이 신원 확인된 개발자에게 등록되어 있어야 함)에 맞춰 패키지명을 Play Console에 등록한다. 이 폴더는 그 등록과, 나중에 Play 등록정보를 만들 때 쓸 자료를 모은 것이다.

- 공식 안내: [Register on Google Play Console](https://developer.android.com/developer-verification/guides/google-play-console) · [Android developer verification](https://developer.android.com/developer-verification/guides)
- 첫 시행 국가(브라질·인도네시아·싱가포르·태국)는 2026-09-30부터 미등록 앱의 설치가 막히고, 이후 전 세계로 확대된다.

## 1. 패키지명 등록 (Play 밖 배포 앱)

| 항목 | 값 |
| --- | --- |
| 패키지명 | `com.jeiel85.myfarm` |
| 서명 인증서 SHA-256 | `5E:DF:AB:48:BC:C2:40:3C:3A:F7:16:F0:C3:D8:C3:76:99:29:46:90:12:C2:C8:97:CA:B9:D8:01:74:AA:70:3B` |
| 인증서 DN | `CN=jeiel85, OU=my-farm-flutter, O=jeiel85, C=KR` |
| 서명 키 | `.keystore/my-farm-upload.jks`(저장소 밖, 커밋 금지) — GitHub 릴리스 APK와 같은 키 |

SHA-256은 공개 인증서의 지문이라 공개해도 된다. 다시 확인하려면 서명된 APK에서 읽는다(비밀번호 불필요).

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

절차(Play Console, 개발자 계정으로 로그인):

1. 왼쪽 메뉴 **Android developer verification** 페이지로 간다. 개발자 신원 확인이 끝나 있어야 등록할 수 있다(설정 → 개발자 계정에서 확인).
2. Play 밖에서 배포하는 앱의 패키지명 등록을 고르고 패키지명 `com.jeiel85.myfarm`을 입력한다.
3. 공개 키로 위 SHA-256 지문을 입력하거나, 목록에 나오면 그 지문을 고른다.
   - Android가 처음 보는 패키지명이면 여기서 등록이 끝난다.
   - 이미 설치된 적이 있는 패키지명이라 **소유 증명**을 요구하면 4로 간다.
4. Play Console이 보여 주는 스니펫을 그대로 파일로 저장하고(안내된 파일 이름 그대로), 증명용 APK를 만든다.

   ```bash
   pwsh tool/play_ownership_apk.ps1 -Snippet <저장한 스니펫 파일> -FileName <안내된 파일 이름>
   ```

   스크립트가 스니펫을 `android/app/src/main/assets/`에 넣고 배포 키로 서명한 APK를 `build/play-ownership/my-farm-ownership.apk`로 만든 뒤, 스니펫 파일은 지운다. 이 APK를 Play Console에 올리면 된다(배포용 APK와 별개).
5. 등록이 끝나면 이메일이 오고, 같은 페이지에 등록 상태가 나온다.

> 이 저장소의 GitHub 릴리스 APK도 같은 키로 서명하므로, 등록 후 별도로 할 일은 없다. 서명 키를 바꾸면 새 키도 같은 페이지에서 추가 등록해야 한다.

## 2. Play 등록정보 자료 (나중에 스토어에 올릴 때)

| 파일 | 규격 |
| --- | --- |
| `icon-512.png` | 앱 아이콘 512×512, 32비트 PNG |
| `feature-graphic-1024x500.png` | 그래픽 이미지 1024×500 |
| `screenshots/phone-ko-1..7.png` | 휴대폰 스크린샷 1080×1920(9:16), 한국어 |

스크린샷은 에뮬레이터(Android 16)에서 예시 농장으로 찍은 화면에 설명을 붙인 것이다. 영어 스크린샷과 태블릿 스크린샷은 아직 없다.

### 앱 이름·설명

**한국어(기본)**

- 앱 이름(30자): `마이팜 - 농장 지도 관리`
- 간단한 설명(80자): `작물·가축·물주기·수확·장부를 농장 지도 한 장에서 관리하는 기기 안 농장 앱`
- 자세한 설명:

```
마이팜은 농장 전체를 지도 한 장으로 보여 주는 농장 관리 앱입니다.

■ 농장 지도
9개 구역(주택·토마토·채소·옥수수·가축·물탱크·창고·온실·과수원)을 눌러 생육률, 다음 물주기, 수확까지 남은 날을 바로 확인해요.

■ 오늘 확인할 것
물주기 지연, 급이 시간, 백신·진료 일정, 수확 가능, 재고 부족을 홈에 자동으로 모아 줘요.

■ 가축 관리
입식·출하·폐사 기록, 급이 타임라인(완료하면 사료 재고 자동 차감), 백신·검진·구충 반복 일정.

■ 매출·비용 장부
작물·가축 판매와 사료·종자·인건비 같은 비용을 적고 월별 순이익을 봐요. 출하·수확을 기록할 때 판매 금액을 함께 적을 수 있고, CSV로 내보내 엑셀에서 열 수 있어요.

■ 알림
물주기·급이·백신 일정 시각에 알림을 받아요(켰을 때만).

■ 날씨와 작업 조언
농장 위치의 5일 예보와 비·폭염·서리·강풍 조언. 연결이 끊겨도 마지막 날씨를 보여 줘요.

■ 기기 안에 저장
계정·광고·분석 SDK가 없고, 기록은 개발자 서버로 보내지 않고 기기 안에 저장돼요. 백업 파일로 내보내고 복원할 수 있어요.
```

**English**

- App name: `My Farm - Farm Map Manager`
- Short description: `Manage crops, livestock, watering, harvests and a ledger on one farm map.`
- Full description:

```
My Farm shows your whole farm on a single map.

• Farm map — tap any of nine zones to see growth, the next watering and days to harvest.
• To check today — overdue watering, feeding times, vaccine and checkup schedules, harvest-ready fields and low stock, collected on the home screen.
• Livestock — arrivals, sales and losses, a feeding timeline that deducts feed stock, and repeating vaccine and checkup schedules.
• Income & expense ledger — record sales and costs, see monthly profit, add the sale amount while recording a harvest or sale, and export CSV for spreadsheets.
• Reminders — optional notifications for watering, feeding and care schedules.
• Weather & advice — a 5-day forecast for your farm with tips for rain, heat, frost and wind; the last forecast stays available offline.
• On your device — no accounts, ads or analytics; nothing is sent to the developer. Back up and restore your records as a file.
```

### 기타 입력값

| 항목 | 권장 값 | 비고 |
| --- | --- | --- |
| 카테고리 | 생산성(Productivity) | |
| 개인정보처리방침 URL | `https://jeiel85.github.io/my-farm-flutter/privacy.html` | `site/privacy.html`, Pages로 배포 |
| 연락처 이메일 | 개발자 계정에서 입력 | 저장소에는 적지 않는다 |
| 광고 | 없음 | |
| 대상 연령 | 18세 이상(또는 13세 이상) | 아동 대상 아님 |

**데이터 보안(Data safety) 초안** — 제출 전 사용자가 최종 판단한다.

- 개발자에게 전송·수집하는 데이터: 없음.
- 날씨 조회 때 사용자가 입력한 농장 위도·경도를 앱이 Open-Meteo로 직접 보낸다. Play 기준으로 "대략적인 위치를 수집(앱 기능 목적, 공유 아님)"으로 신고하는 것이 보수적이다. 기기 위치 권한은 쓰지 않는다.
- 전송 중 암호화: 예(HTTPS). 데이터 삭제: 기록은 기기에 있어 앱 삭제·초기화로 지워진다. 단 Android 시스템 백업(사용자 Google 계정, `allowBackup` 기본값)에 들어갈 수 있고, 이는 Play 데이터 보안의 개발자 수집에 해당하지 않는다(개발자 접근 불가).
