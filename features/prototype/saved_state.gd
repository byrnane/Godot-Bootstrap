extends RefCounted

static func number(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback

static func point(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or value.size() != 3:
		return fallback
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return fallback
	var candidate: Vector3 = Vector3(value[0], value[1], value[2])
	if absf(candidate.x) >= 4.8 or candidate.z < -29.1 or candidate.z > 4.1 or candidate.y < -0.1 or candidate.y >= 3.0:
		return fallback
	candidate.y = maxf(candidate.y, 0.0)
	return candidate
