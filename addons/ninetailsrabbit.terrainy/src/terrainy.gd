@tool
extends Node

@export var button_Generate_Terrain: String
## More resolution means more detail (more dense vertex) in the terrain generation, this increases the mesh subdivisions it could reduce the performance in low-spec pcs
@export_range(1, 16, 1) var mesh_resolution: int = 1:
	set(value):
		if value != mesh_resolution:
			mesh_resolution = value
			
			generate_terrain()
## The depth size of the mesh (z) in godot units (meters)
@export var size_depth: int = 100:
	set(value):
		if value != size_depth:
			size_depth = max(1, value)
			
			generate_terrain()
			
## The width size of the mesh (x) in godot units (meters)
@export var size_width: int = 100:
	set(value):
		if value != size_width:
			size_width = max(1, value)
			
			generate_terrain()
## The maximum height this terrain can have
@export var max_terrain_height: float = 50.0:
	set(value):
		if value != max_terrain_height:
			max_terrain_height = maxf(0.5, value)
			generate_terrain()
## If no target mesh is set, a PlaneMesh is created by default
@export var target_mesh: MeshInstance3D:
	set(value):
		if value != target_mesh:
			target_mesh = value
			update_configuration_warnings()
			
## The terrain material that will be applied on the surface
@export var terrain_material: Material
## Noise values are perfect to generate a variety of surfaces, higher frequencies tend to generate more mountainous terrain.
@export var noise: FastNoiseLite:
	set(value):
		if value != noise:
			noise = value
			update_configuration_warnings()


func _get_configuration_warnings():
	var warnings: PackedStringArray = []
	
	if target_mesh == null:
		warnings.append("No target mesh found. Expected a MeshInstance3D")
	
	if noise == null:
		warnings.append("No noise found. Expected a FastNoiseLite")
		
	return warnings
	

func _ready() -> void:
	generate_terrain()


func generate_terrain() -> void:
	if target_mesh == null:
		push_warning("Terrainy: This node needs a target_mesh value to create the terrain, aborting generation...")
		return
	
	if noise == null:
		push_warning("Terrainy: This node needs a noise value to create the terrain, aborting generation...")
		return
		
	_set_owner_to_edited_scene_root(target_mesh)
	
	if target_mesh.mesh is PlaneMesh:
		set_terrain_size_on_plane_mesh(target_mesh.mesh)
	elif target_mesh.mesh is QuadMesh:
		set_terrain_size_on_plane_mesh(target_mesh.mesh)
	elif  target_mesh.mesh is BoxMesh:
		set_terrain_size_on_box_mesh(target_mesh.mesh)
	elif target_mesh.mesh is PrismMesh:
		set_terrain_size_on_prism_mesh(target_mesh.mesh)
	elif target_mesh.mesh is ArrayMesh:
		target_mesh.mesh = null
	
	if target_mesh.mesh == null:
		var plane_mesh = PlaneMesh.new()
		set_terrain_size_on_plane_mesh(plane_mesh)
		target_mesh.mesh = plane_mesh
		
	_free_children(target_mesh)
	create_surface(target_mesh)
	

func create_surface(mesh_instance: MeshInstance3D = target_mesh) -> void:
	var surface = SurfaceTool.new()
	var mesh_data_tool = MeshDataTool.new()
	
	surface.create_from(mesh_instance.mesh, 0)

	var array_mesh = surface.commit()
	mesh_data_tool.create_from_surface(array_mesh, 0)
	
	for vertex_idx: int in mesh_data_tool.get_vertex_count():
		var vertex: Vector3 = mesh_data_tool.get_vertex(vertex_idx)
		vertex.y = noise.get_noise_2d(vertex.x, vertex.z) * max_terrain_height
		
		mesh_data_tool.set_vertex(vertex_idx, vertex)
	
	array_mesh.clear_surfaces()
	mesh_data_tool.commit_to_surface(array_mesh)
	
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.create_from(array_mesh, 0)
	surface.generate_normals()

	mesh_instance.mesh = surface.commit()
	mesh_instance.create_trimesh_collision()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	

func set_terrain_size_on_plane_mesh(plane_mesh: PlaneMesh) -> void:
	plane_mesh.size = Vector2(size_width, size_depth)
	plane_mesh.subdivide_depth = size_depth
	plane_mesh.subdivide_width = size_width
	plane_mesh.material = terrain_material
	

func set_terrain_size_on_box_mesh(box_mesh: BoxMesh) -> void:
	box_mesh.size = Vector3(size_width, box_mesh.size.y, size_depth)
	box_mesh.subdivide_depth = size_depth
	box_mesh.subdivide_width = size_width
	box_mesh.material = terrain_material


func set_terrain_size_on_prism_mesh(prism_mesh: PrismMesh) -> void:
	prism_mesh.size = Vector3(size_width, prism_mesh.size.y, size_depth)
	prism_mesh.subdivide_depth = size_depth
	prism_mesh.subdivide_width = size_width
	prism_mesh.material = terrain_material

#region Helpers
func _set_owner_to_edited_scene_root(node: Node) -> void:
	if Engine.is_editor_hint() and node.get_tree():
		node.owner = node.get_tree().edited_scene_root


func _free_children(node: Node) -> void:
	if node.get_child_count() == 0:
		return

	var childrens = node.get_children()
	childrens.reverse()
	
	for child in childrens.filter(func(_node: Node): return is_instance_valid(node)):
		child.free()


func _on_tool_button_pressed(text: String) -> void:
	match text:
		"Generate Terrain":
			generate_terrain()

#endregion