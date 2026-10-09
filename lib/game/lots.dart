/// 땅 한 칸의 좌표. docs/farm-lots-design.md §3.
///
/// 땅은 [landCols] × [landRows] 격자이고, 칸마다 하나의 건물(또는 빈 땅·장애물)이 있다.
library;

const landCols = 4;
const landRows = 5;

class LotId implements Comparable<LotId> {
  const LotId(this.col, this.row);

  final int col;
  final int row;

  /// 저장할 때 쓰는 키("열,행").
  String get key => '$col,$row';

  static LotId parse(String key) {
    final parts = key.split(',');
    if (parts.length != 2) throw FormatException('Bad lot id', key);
    return LotId(int.parse(parts[0]), int.parse(parts[1]));
  }

  bool get inLand => col >= 0 && col < landCols && row >= 0 && row < landRows;

  /// 상하좌우로 붙은 칸(땅 안만).
  List<LotId> get neighbors => [
    LotId(col, row - 1),
    LotId(col - 1, row),
    LotId(col + 1, row),
    LotId(col, row + 1),
  ].where((l) => l.inLand).toList();

  /// 땅 전체 칸(위에서 아래, 왼쪽에서 오른쪽).
  static final List<LotId> all = [
    for (var r = 0; r < landRows; r++)
      for (var c = 0; c < landCols; c++) LotId(c, r),
  ];

  @override
  int compareTo(LotId other) => row != other.row ? row.compareTo(other.row) : col.compareTo(other.col);

  @override
  bool operator ==(Object other) => other is LotId && other.col == col && other.row == row;

  @override
  int get hashCode => col * 31 + row;

  @override
  String toString() => 'LotId($key)';
}
