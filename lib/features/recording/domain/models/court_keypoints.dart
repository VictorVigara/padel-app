/// Defines the 12 court keypoints used for homography calibration.
///
/// Each entry holds:
///   - [index]   0-based position in the tap sequence
///   - [label]   short identifier shown in the instruction bar (e.g. "k1")
///   - [name]    human-readable description shown to the user
///   - [xMeters] real-world X coordinate on court (0–10 m, left baseline = 0)
///   - [yMeters] real-world Y coordinate on court (0–20 m, near baseline = 0)
class CourtKeypoint {
  final int index;
  final String label;
  final String name;
  final double xMeters;
  final double yMeters;

  const CourtKeypoint({
    required this.index,
    required this.label,
    required this.name,
    required this.xMeters,
    required this.yMeters,
  });
}

const List<CourtKeypoint> courtKeypoints = [
  CourtKeypoint(index: 0,  label: 'k1',  name: 'near baseline left',      xMeters:  0, yMeters:  0),
  CourtKeypoint(index: 1,  label: 'k2',  name: 'near baseline right',     xMeters: 10, yMeters:  0),
  CourtKeypoint(index: 2,  label: 'k3',  name: 'near service line left',  xMeters:  0, yMeters:  3),
  CourtKeypoint(index: 3,  label: 'k4',  name: 'near service line center',xMeters:  5, yMeters:  3),
  CourtKeypoint(index: 4,  label: 'k5',  name: 'near service line right', xMeters: 10, yMeters:  3),
  CourtKeypoint(index: 5,  label: 'k6',  name: 'net left',                xMeters:  0, yMeters: 10),
  CourtKeypoint(index: 6,  label: 'k7',  name: 'net right',               xMeters: 10, yMeters: 10),
  CourtKeypoint(index: 7,  label: 'k8',  name: 'far service line left',   xMeters:  0, yMeters: 17),
  CourtKeypoint(index: 8,  label: 'k9',  name: 'far service line center', xMeters:  5, yMeters: 17),
  CourtKeypoint(index: 9,  label: 'k10', name: 'far service line right',  xMeters: 10, yMeters: 17),
  CourtKeypoint(index: 10, label: 'k11', name: 'far baseline left',       xMeters:  0, yMeters: 20),
  CourtKeypoint(index: 11, label: 'k12', name: 'far baseline right',      xMeters: 10, yMeters: 20),
];
