# 마이팜 (my-farm-flutter)

위에서 내려다본 농장 지도로 작물·가축·물·수확을 한 화면에서 관리하는 Flutter 앱입니다.
구역 칩이나 지도를 누르면 카메라가 그 구역으로 부드럽게 날아가고, 소·양·닭은 목장 안을 돌아다니고 트랙터는 길을 따라 움직입니다.

인스타그램의 "Flutter로 만든 농장 앱 UI" 영상에서 영감을 받아, 화면 구성(농장 지도 + 구역 칩 + 구역 카드 + 가축 관리)을 처음부터 다시 구현하고 실제로 기록이 남는 기능을 더했습니다. 그림 에셋 없이 지도·가축을 모두 코드(`CustomPainter`)로 그립니다.

| 홈 | 농장 지도 | 구역 확대 | 가축 관리 |
| --- | --- | --- | --- |
| ![홈](docs/screenshots/home.png) | ![농장](docs/screenshots/farm.png) | ![구역](docs/screenshots/zone.png) | ![가축](docs/screenshots/livestock.png) |

| 분석 | 날씨 | 전체 화면 지도 |
| --- | --- | --- |
| ![분석](docs/screenshots/analytics.png) | ![날씨](docs/screenshots/weather.png) | ![전체 지도](docs/screenshots/fullmap.png) |

## 기능

**영상에 있던 것**
- 농장 지도: 농가·토마토·채소·옥수수·가축·물탱크·창고 구역, 구역 칩을 고르면 카메라가 이동하고 테두리로 강조
- 구역 카드: 작물 생육률(칸 막대), 상태, 다음 물주기, 수확까지 남은 날 / 가축 수·건강·다음 급이 / 물탱크 수위·저장량·오늘 사용량
- 가축 관리: 건강·사료·생산 원형 게이지, 오늘의 급이 타임라인(눌러서 완료 체크), 종류별(소·닭·양·염소) 목록과 개체 상세

**더한 농장 요소**
- 지도 구역 2곳 추가: **온실**(딸기)과 **과수원·양봉장**(사과나무, 벌통 주변을 나는 벌)
- **물주기**: 밭마다 관수 주기·1회 사용량이 있고, 물을 주면 물탱크에서 차감됩니다. "스마트 관수"는 2시간 안에 물이 필요한 밭에 탱크 잔량이 허락하는 만큼 물을 줍니다. 물이 필요한 밭은 지도에 파란 점이 깜빡입니다.
- **수확 기록**: 작물별 수확량을 기록하고, 원하면 같은 밭에 바로 다시 심어 생육률을 0%부터 다시 계산합니다.
- **생산 기록**: 하루 달걀·우유 생산량을 목표와 비교합니다.
- **재고**: 사료·종자·비료·자재의 입고/사용 기록, 하루 소비량으로 남은 일수 계산, 기준 이하이면 부족 표시
- **날씨**: 농장 위치의 현재 날씨와 5일 예보(Open-Meteo), 강수·폭염·서리·강풍에 따른 작업 조언
- **오늘 할 일**과 **오늘 확인할 것**(물주기·급이 지연·수확 가능·재고 부족·관리 필요 가축을 자동으로 모아 보여 줌)
- **분석**: 7/14/30일 달걀·우유 추이(목표선 포함), 일별 물 사용량, 작물별 누적 수확

더 넣을 만한 요소는 [BACKLOG.md](BACKLOG.md)에 정리했습니다.

## 기술 선택

| 항목 | 선택 | 이유 |
| --- | --- | --- |
| 프레임워크 | Flutter 3.47 (Dart 3.13) | 원본 영상이 Flutter였고, 지도·애니메이션을 한 코드로 Android·iOS·웹에 그대로 그릴 수 있습니다. 원본이 iOS 시뮬레이터에서 시연된 앱이라 Android 전용 네이티브보다 크로스플랫폼이 맞다고 판단했습니다. |
| 렌더링 | `CustomPainter` + `ui.Picture` 캐시 | 움직이지 않는 지형·작물은 한 번만 그려 재사용하고, 동물·트랙터·물결만 매 프레임 그립니다. |
| 상태 | `ChangeNotifier` + `InheritedNotifier` | 화면 수에 비해 상태가 단순해 별도 상태관리 패키지를 쓰지 않았습니다. |
| 저장 | `shared_preferences`(JSON 한 덩어리, `schemaVersion` 포함) | 기기 안에만 저장합니다. 읽을 수 없는 저장본은 지우지 않고 별도 키로 보관한 뒤 예시 농장으로 시작합니다. |
| 애니메이션 | `flutter_animate`, 암시적 애니메이션 | 목록 진입, 카드 전환, 게이지 차오름 |
| 차트 | `fl_chart` | |
| 날씨 | [Open-Meteo](https://open-meteo.com/) | API 키가 필요 없고 무료입니다(CC BY 4.0, 앱 안에 출처 표기). |

## 구조

```
lib/
  main.dart, app_shell.dart        앱 시작, 하단 탭
  core/                            테마, 공통 위젯, 가축 아이콘 painter
  data/                            모델, 저장(FarmStore), 예시 데이터, 날씨
  features/
    farm/                          농장 지도(farm_world.dart: 지형·애니메이션, farm_map_view.dart: 카메라)
    livestock/ crops/ harvest/ analytics/ inventory/ weather/ home/ profile/
test/                              상태 로직·날씨 파싱·앱 스모크 테스트
```

## 빌드

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

릴리스 빌드는 업로드 키로 서명합니다. 서명 정보가 없으면 디버그 키로 조용히 대체하지 않고 빌드를 멈춥니다. 값은 환경변수가 우선이고, 없으면 저장소 루트의 `.keystore/release-signing.properties`(커밋 금지, `.gitignore` 처리)를 읽습니다.

| 환경변수 | properties 키 | 기본값 |
| --- | --- | --- |
| `KEYSTORE_PATH` | `keystorePath` | `../.keystore/my-farm-upload.jks` (android/ 기준) |
| `STORE_PASSWORD` | `storePassword` | 없음(필수) |
| `KEY_ALIAS` | `keyAlias` | `my-farm` |
| `KEY_PASSWORD` | `keyPassword` | 없음 |

Windows에서 Pub 캐시(C:)와 프로젝트(D:)의 드라이브가 다르면 Kotlin 증분 컴파일 캐시가 실패하므로 `android/gradle.properties`에서 `kotlin.incremental=false`로 꺼 두었습니다.

## 데이터와 개인정보

- 모든 기록은 기기 안에만 저장되며, 계정·분석·광고 SDK가 없습니다.
- 네트워크는 날씨 조회에만 쓰며, 프로필에 입력한 위도·경도만 Open-Meteo로 전송됩니다.
- 처음 실행하면 예시 농장("초록골 농장")이 채워져 있습니다. 프로필 → "예시 농장으로 초기화"로 언제든 되돌릴 수 있습니다.

## 라이선스

[MIT](LICENSE)
