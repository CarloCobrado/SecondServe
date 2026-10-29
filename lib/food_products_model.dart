import 'dart:convert';

List<Datum> parseProductsFromJson(String str) {
  final dynamic decoded = json.decode(str);

  List<dynamic> jsonList;
  if (decoded is List) {
    jsonList = decoded;
  } else if (decoded is Map<String, dynamic>) {
    jsonList = decoded["products"] as List<dynamic>? ??
        decoded["data"] as List<dynamic>? ??
        [];
  } else {
    throw const FormatException(
      'Invalid JSON format: Expected a JSON Array or an Object with a "products" array.',
    );
  }

  return jsonList
      .map((item) => Datum.fromJson(item as Map<String, dynamic>))
      .toList();
}

FoodProducts foodProductsFromJson(String str) =>
    FoodProducts(products: parseProductsFromJson(str));

String foodProductsToJson(FoodProducts data) => json.encode(data.toJson());

typedef Product = Datum;

class FoodProducts {
  FoodProducts({
    required this.products,
  });

  final List<Datum> products;

  factory FoodProducts.fromJson(Map<String, dynamic> json) => FoodProducts(
        products: List<Datum>.from(
          (json["products"] as List<dynamic>).map(
            (x) => Datum.fromJson(x as Map<String, dynamic>),
          ),
        ),
      );

  Map<String, dynamic> toJson() => {
        "products": List<dynamic>.from(products.map((x) => x.toJson())),
      };
}

class Datum {
  Datum({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.price,
    required this.availableServings,
    required this.imageUrl,
  });

  final int id;
  final String name;
  final String category;
  final String location;
  final String price;
  final String availableServings;
  final String imageUrl;

  bool get isAssetImage => imageUrl.startsWith('assets/');

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"] is int ? json["id"] : (int.tryParse('${json["id"]}') ?? 0),
        name: json["name"]?.toString() ?? '',
        category: json["category"]?.toString() ?? 'Surplus Food',
        location: json["location"]?.toString() ?? '',
        price: json["price"]?.toString() ?? '',
        availableServings: (json["available_servings"] ?? json["serving_size"])?.toString() ?? '',
        imageUrl: json["image_url"]?.toString() ?? 'assets/icons/TempLogo.jpg',
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "category": category,
        "location": location,
        "price": price,
        "available_servings": availableServings,
        "image_url": imageUrl,
      };
}
