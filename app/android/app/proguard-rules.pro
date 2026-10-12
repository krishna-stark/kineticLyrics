# Ads transitively uses Room 2.2.5 / WorkManager. Its old class-only rule
# does not retain the reflective zero-argument constructor in AGP 9 full mode.
# Match modern Room's consumer rule without disabling release optimization.
-keep class * extends androidx.room.RoomDatabase { void <init>(); }
# The same older WorkManager dependency reflects its input mergers.
-keep class * extends androidx.work.InputMerger { public <init>(); }
