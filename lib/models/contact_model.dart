class ContactModel {
  final String? id;
  final String? displayName;
  final String? phoneNumber;
  final String? email;
  final String? company;
  final String? address;
  final String? photo;
  final bool isFavorite;

  ContactModel({
    this.id,
    this.displayName,
    this.phoneNumber,
    this.email,
    this.company,
    this.address,
    this.photo,
    this.isFavorite = false,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      company: json['company'],
      address: json['address'],
      photo: json['photo'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'email': email,
      'company': company,
      'address': address,
      'photo': photo,
      'isFavorite': isFavorite,
    };
  }

  ContactModel copyWith({
    String? id,
    String? displayName,
    String? phoneNumber,
    String? email,
    String? company,
    String? address,
    String? photo,
    bool? isFavorite,
  }) {
    return ContactModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      company: company ?? this.company,
      address: address ?? this.address,
      photo: photo ?? this.photo,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
