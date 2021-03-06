using afIoc::Inject

internal class TestPropertyType : MorphiaTest {
	
	@Inject Converters? serialiser
	
	Void testDeserialize() {
		mongoDoc := ["_id":-1, "inty" : 42]
		
		entity := (T_Entity16) serialiser.toFantom(T_Entity16#, mongoDoc)
		
		verifyEq(entity.inty, 42)
		verifyEq(entity.inty.typeof, Int#)
	}
	
	Void testSerialize() {
		entity := T_Entity16() { inty = 42 }
		
		mongoDoc := serialiser.toMongo(T_Entity16#, entity) as Map
		
		verifyEq(mongoDoc["inty"],	42)
		verifyEq(mongoDoc["inty"].typeof, Int#)
	}
}

@Entity
internal class T_Entity16 {
	@Property Int _id
	@Property { implType=Int# }	Num	inty
	new make(|This|in) { in(this) }
}
