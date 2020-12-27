import 'dart:async';

import 'package:flutter/material.dart';
import 'package:v2g_app/charging.dart';
import 'package:v2g_app/service/api_service.dart';
import 'package:v2g_app/util/Resources.dart';

class V2GScreen extends StatefulWidget {
  V2GScreen(this.data);
  final data;
  @override
  _V2GScreenState createState() => _V2GScreenState();
}

class _V2GScreenState extends State<V2GScreen> {
  var _api_service = APIService();
  var vehicle_data = null;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer.periodic(Duration(seconds: 10), (Timer t) {
      getVehicleDetails(t);
    });
  }

  getVehicleDetails(Timer t) async {
    // EasyLoading.show(status: 'loading...');
    var vehicle = await _api_service.getVehicle(Resources.VEHICLE_ID);

    // print(vehicle);
    if (vehicle != null) {
      vehicle_data = Map();
      vehicle_data['id'] = vehicle['vehicleID'];
      vehicle_data['soc'] = vehicle['curr_soc'];

      vehicle_data['StartAt'] =
          DateTime.parse(vehicle['start_time']).millisecondsSinceEpoch;
      vehicle_data['EndAt'] =
          DateTime.parse(vehicle['user_config']['t_out_time'])
              .millisecondsSinceEpoch;
      if (vehicle['user_config']['charging'] != null) {
        vehicle_data['charge_mode'] = Resources.CHARGING_MODE_MAP[
            vehicle['user_config']['charging']['charging_mode']];
        vehicle_data['PauseAt'] =
            vehicle['user_config']['charging']['PauseAt'] == null
                ? null
                : DateTime.parse(vehicle['user_config']['charging']['PauseAt'])
                    .millisecondsSinceEpoch;
        vehicle_data['PeakStartAt'] = vehicle['user_config']['charging']
                    ['PeakStartAt'] ==
                null
            ? null
            : DateTime.parse(vehicle['user_config']['charging']['PeakStartAt'])
                .millisecondsSinceEpoch;
      }
      vehicle_data['isV2G'] = vehicle['user_config']['isV2G'];
      vehicle_data['isCharging'] = vehicle['user_config']['isCharging'];

      vehicle_data['mode'] = vehicle['user_config']['isV2G']
          ? Resources.MODE_V2G
          : Resources.MODE_CHARGING;
      print(vehicle_data);
      if (vehicle_data['isV2G']) {
        setState(() {});
      } else {
        t.cancel();
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ChargingScreen(vehicle_data)));
      }
    }

    // EasyLoading.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    // getVehicleDetails();
    var data = vehicle_data != null ? vehicle_data : widget.data;
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Text("V2G Enabled."),
            Text("SOC : " + data['soc'].toString())
          ],
        ),
      ),
    );
  }
}
