class AddressModel {
  String fullName;
  int phoneNum;
  bool isDefault;
  String street;
  String city;
  String state;
  String zipCode;

  AddressModel({
    required this.fullName,
    required this.phoneNum,
    required this.isDefault,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      fullName: json['fullName'] ?? '',
      phoneNum: json['phoneNum'] ?? 0,
      isDefault: json['isDefault'] ?? false,
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNum': phoneNum,
      'isDefault': isDefault,
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
    };
  }

  @override
  String toString() {
    return "$fullName, $phoneNum, ${isDefault ? "Default" : "Non-default"}, $street, $city, $state $zipCode";
  }
}
