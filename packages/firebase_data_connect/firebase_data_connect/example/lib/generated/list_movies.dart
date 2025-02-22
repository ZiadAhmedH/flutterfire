part of movies;

class ListMovies {
  String name = "ListMovies";
  ListMovies({required this.dataConnect});

  Deserializer<ListMoviesData> dataDeserializer = (String json) =>
      ListMoviesData.fromJson(jsonDecode(json) as Map<String, dynamic>);

  QueryRef<ListMoviesData, void> ref() {
    return dataConnect.query(
        this.name, dataDeserializer, emptySerializer, null);
  }

  FirebaseDataConnect dataConnect;
}

class ListMoviesMovies {
  late String id;

  late String title;

  late List<ListMoviesMoviesDirectedBy> directed_by;

  ListMoviesMovies.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        directed_by = (json['directed_by'] as List<dynamic>)
            .map((e) => ListMoviesMoviesDirectedBy.fromJson(e))
            .toList() {}

  // TODO: Fix up to create a map on the fly
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};

    json['id'] = id;

    json['title'] = title;

    json['directed_by'] = directed_by.map((e) => e.toJson()).toList();

    return json;
  }

  ListMoviesMovies({
    required this.id,
    required this.title,
    required this.directed_by,
  }) {
    // TODO: Only show this if there are optional fields.
  }
}

class ListMoviesMoviesDirectedBy {
  late String name;

  ListMoviesMoviesDirectedBy.fromJson(Map<String, dynamic> json)
      : name = json['name'] {}

  // TODO: Fix up to create a map on the fly
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};

    json['name'] = name;

    return json;
  }

  ListMoviesMoviesDirectedBy({
    required this.name,
  }) {
    // TODO: Only show this if there are optional fields.
  }
}

class ListMoviesData {
  late List<ListMoviesMovies> movies;

  ListMoviesData.fromJson(Map<String, dynamic> json)
      : movies = (json['movies'] as List<dynamic>)
            .map((e) => ListMoviesMovies.fromJson(e))
            .toList() {}

  // TODO: Fix up to create a map on the fly
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};

    json['movies'] = movies.map((e) => e.toJson()).toList();

    return json;
  }

  ListMoviesData({
    required this.movies,
  }) {
    // TODO: Only show this if there are optional fields.
  }
}
