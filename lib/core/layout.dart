import 'package:flutter/material.dart';

/// 이 폭부터 PC·태블릿 가로 배치(옆 메뉴 + 두 열)를 쓴다. 그보다 좁으면 휴대폰 배치 그대로다.
const wideBreakpoint = 900.0;

/// 넓은 화면에서 본문이 지나치게 늘어나지 않게 하는 최대 폭.
const wideContentMaxWidth = 1240.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// 휴대폰에서는 [primary] 다음에 [secondary]를 이어 붙인 한 목록, 넓은 화면에서는 두 열로 나란히 보여 준다.
///
/// 두 열은 한 번에 스크롤한다(각 열이 따로 스크롤되면 마우스 위치에 따라 움직이는 쪽이 달라 헷갈린다).
class SplitList extends StatelessWidget {
  const SplitList({
    super.key,
    required this.primary,
    required this.secondary,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 28),
    this.widePadding = const EdgeInsets.fromLTRB(28, 16, 28, 32),
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.gap = 24,
    this.controller,
  });

  final List<Widget> primary;
  final List<Widget> secondary;

  /// 휴대폰 배치의 목록 여백(기존 화면과 같게 둔다).
  final EdgeInsets padding;
  final EdgeInsets widePadding;
  final int primaryFlex;
  final int secondaryFlex;
  final double gap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) {
      return ListView(controller: controller, padding: padding, children: [...primary, ...secondary]);
    }
    // ListView로 감싸 높이를 꽉 채운다(SingleChildScrollView는 내용만큼만 차지해서, 탭 전환 Stack이 가운데로 띄운다).
    return ListView(
      controller: controller,
      padding: widePadding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: wideContentMaxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: primaryFlex,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: primary),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: secondaryFlex,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: secondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 한 열짜리 화면(상세 화면 등)을 넓은 화면에서 가운데 [maxWidth] 폭으로 모은다. 휴대폰에서는 그대로다.
class WideBody extends StatelessWidget {
  const WideBody({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
