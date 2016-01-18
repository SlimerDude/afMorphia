using afBeanUtils::ReflectUtils
using afIoc
using afBson
using afMongo

** The main converter for MongoDB documents. 
** 
** @see [Storing null vs not storing the key at all in MongoDB]`http://stackoverflow.com/questions/12403240/storing-null-vs-not-storing-the-key-at-all-in-mongodb` 
@NoDoc	// public so people can change the null strategy
const class ObjConverter : Converter {

	@Inject private const |->Scope|			activeScope
	@Inject private const |->Converters|	converters
			private const Bool				storeNullFields
	
	** Creates a new 'DocumentConverter' with the given 'null' strategy.
	** 
	** If 'storeNullFields' is 'false' then properties with 'null' values are not stored in the database.
	new make(Bool storeNullFields, |This|in) {
		this.storeNullFields = storeNullFields
		in(this) 
	}
	
	@NoDoc
	override Obj? toFantom(Type fantomType, Obj? mongoObj) {
		if (mongoObj == null) return null

		// because ObjConverter is a catch-all converter, we sometimes get sent here by mistake
		if (mongoObj.typeof.name != "Map")
			throw MorphiaErr(ErrMsgs.documentConv_noConverter(fantomType, mongoObj))

		mongoDoc	:= (Str:Obj?) mongoObj
		fieldVals	:= [Field:Obj?][:]

		fantomType.fields.each |field| {
			property := (Property?) Field#.method("facet").callOn(field, [Property#, false])
			if (property == null)
				return
			
			propName := property.name ?: field.name
			implType := property.type ?: field.type
			propVal  := mongoDoc.get(propName, null)
			
			fieldVal := converters().toFantom(implType, propVal)
			
			if (fieldVal == null && !field.type.isNullable) {
				// a value *is* required so decide which Err msg to throw 
				if (mongoDoc.containsKey(propName))
					throw MorphiaErr(ErrMsgs.documentConv_propertyIsNull(propName, field, logDoc(mongoDoc)))
				else 
					throw MorphiaErr(ErrMsgs.documentConv_propertyNotFound(field, logDoc(mongoDoc)))
			}
	
			// sanity check we're about to set the correct instance 
			if (fieldVal != null && !ReflectUtils.fits(fieldVal.typeof, field.type))
				throw MorphiaErr(ErrMsgs.documentConv_propertyDoesNotFitField(propName, fieldVal.typeof, field, logDoc(mongoDoc)))

			fieldVals[field] = fieldVal
		}
		return createEntity(fantomType, fieldVals)
	}
	
	@NoDoc
	override Obj? toMongo(Type type, Obj? fantomObj) {
		if (fantomObj == null) return null
		mongoDoc := createJsonObj
		
		fantomObj.typeof.fields.each |field| {
			property := (Property?) Field#.method("facet").callOn(field, [Property#, false])
			if (property == null)
				return

			fieldVal := field.get(fantomObj)
			propName := property.name ?: field.name			
			
			// should we recursively convert...? 
			propVal	 := converters().toMongo(fieldVal?.typeof ?: field.type, fieldVal)			
			
			if (propVal == null && !storeNullFields)
				return

			// use add, rather than set, so an Err is thrown should we accidently try to add the 
			// same name twice (from using the Property@name facet)
			mongoDoc.add(propName, propVal)
		}

		return mongoDoc
	}

	** An overridable hook that uses IoC to autobuild an Entity instance.
	virtual Obj? createEntity(Type type, Field:Obj? fieldVals) {
		activeScope().build(type, null, fieldVals)
	}
	
	** Creates an empty *ordered* map. Override if you prefer your JSON maps to be unordered or case-insensitive.
	virtual Str:Obj? createJsonObj() {
		Str:Obj?[:] { it.ordered = true }
	}
	
	private static const Type[] literals	:= [Bool#, Buf#, Date#, DateTime#, Decimal#, Duration#, Enum#, Float#, Int#, ObjectId#, Regex#, Range#, Slot#, Str#, Type#]

	private Str:Str logDoc(Str:Obj? document) {
		document.map |val->Str| {
			if (val == null)
				return "null"
			if (literals.contains(val.typeof.toNonNullable))
				return val.toStr
			return "..." 
		}
	}
}
