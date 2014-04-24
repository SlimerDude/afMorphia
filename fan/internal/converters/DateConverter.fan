
internal const class DateConverter : Converter {

	override Obj? toFantom(Type type, Obj? mongoObj) {
		if (mongoObj == null) return null
		return ((DateTime) mongoObj).date
	}
	
	override Obj? toMongo(Obj fantomObj) {
		((Date) fantomObj).toDateTime(Time.defVal)
	}

}