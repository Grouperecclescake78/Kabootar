/// Bounds that keep the mesh's storage, battery, and flood radius finite.
///
/// A delay-tolerant network carries data on behalf of others, so every one of
/// these is a safety valve: without them a single node would flood forever and
/// hoard messages without limit.
class MeshConfig {
  const MeshConfig({
    this.ttl = 8,
    this.maxCacheSize = 500,
    this.maxAgeMs = 24 * 60 * 60 * 1000, // 24h
    this.seenRetentionMs = 48 * 60 * 60 * 1000, // 48h
  });

  /// Hop budget stamped on a freshly-sent envelope. Each relay decrements it;
  /// at zero the envelope stops propagating. Bounds flood radius.
  final int ttl;

  /// Maximum number of envelopes this node will carry on behalf of others at
  /// once. When exceeded, the oldest carried envelope is evicted.
  final int maxCacheSize;

  /// How long a carried envelope may live before it is pruned, regardless of
  /// cache size. Measured from the originator's send time.
  final int maxAgeMs;

  /// How long a de-dup record is retained. Must comfortably exceed [maxAgeMs]
  /// so an envelope cannot outlive the memory of having seen it (which would
  /// let it re-flood).
  final int seenRetentionMs;

  static const MeshConfig defaults = MeshConfig();
}
