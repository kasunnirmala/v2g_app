import 'package:dio/dio.dart';
import 'package:v2g_app/util/Resources.dart';

class APIService {
  Dio _dio = new Dio(new BaseOptions(
    baseUrl: Resources.BASE_URL,
    connectTimeout: 5000,
    receiveTimeout: 3000,
  ));

  Future addNode(dynamic data) async {
    var response = await _dio.post("/node/add_node", data: data);
    if (response.statusCode == 200) {
      print(response);
      return response.data;
    }
    print("NO DATA");

    return null;
  }

  Future getVehicle(String vehicleID) async {
    var response =
        await _dio.post("/node/vehicle_status", data: {'vehicleID': vehicleID});
    if (response.statusCode == 200) {
      // print(response);
      return response.data;
    }
    print("NO DATA");

    return null;
  }
}
