@tool
extends Resource
## Limits for a family of plants. Angles are measured in degrees from vertical.
@export_range(0, 35, 1) var trunk_lean := 16.0
@export_range(0, 25, 1) var joint_bend := 9.0
@export_range(0, 40, 1) var palm_lean := 28.0
@export_range(5, 75, 1) var branch_angle_min := 28.0
@export_range(5, 75, 1) var branch_angle_max := 55.0
@export_range(0, 0.25, 0.01) var height_variation := 0.16
@export_range(0, 0.3, 0.01) var crown_variation := 0.22
