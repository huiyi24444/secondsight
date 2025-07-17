class AddressModel {
  String fullName;
  int phoneNum;
  bool isDefault;
  String streetone;
  String streettwo;
  String city;
  String state;
  String zipCode;

  AddressModel({
    required this.fullName,
    required this.phoneNum,
    required this.isDefault,
    required this.streetone,
    required this.streettwo,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      fullName: json['fullName'] ?? '',
      phoneNum: json['phoneNum'] ?? 0,
      isDefault: json['isDefault'] ?? false,
      streetone: json['streetone'] ?? '',
      streettwo: json['streettwo'] ?? '',
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
      'streetone': streetone,
      'streettwo': streettwo,
      'city': city,
      'state': state,
      'zipCode': zipCode,
    };
  }

  @override
  String toString() {
    return "$fullName, $phoneNum, ${isDefault ? "Default" : "Non-default"}, $streetone, $streettwo, $city, $state $zipCode";
  }

  Map<String, dynamic> toShipmentMap() {
    return {
      'fullName': fullName,
      'phoneNum': phoneNum,
      'streetone': streetone,
      'streettwo': streettwo,
      'city': city,
      'state': state,
      'zipCode': zipCode,
    };
  }

}
