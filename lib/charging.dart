import 'dart:async';

import 'package:flutter/material.dart';
import 'package:v2g_app/service/api_service.dart';
import 'package:v2g_app/util/Resources.dart';
import 'package:v2g_app/v2g.dart';

class ChargingScreen extends StatefulWidget {
  ChargingScreen(this.data);
  final data;
  @override
  _ChargingScreenState createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Timer.periodic(Duration(seconds: 10), (Timer t) {
      getVehicleDetails(t);
    });
  }

  var _api_service = APIService();
  var vehicle_data = null;
  getVehicleDetails(Timer t) async {
    // EasyLoading.show(status: 'loading...');
    var vehicle = await _api_service.getVehicle(Resources.VEHICLE_ID);

    // print(vehicle);
    if (vehicle != null) {
      vehicle_data = Map();
      vehicle_data['id'] = vehicle['vehicleID'];
      vehicle_data['soc'] = vehicle['curr_soc'];

      var soc_remain = 80 - vehicle['curr_soc'];
      soc_remain = soc_remain * 40 / 100;
      var Tc = soc_remain / Resources.C_RATE;
      Tc = Tc * 3600000;
      vehicle_data['tc'] = Tc/60000;

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
        t.cancel();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => V2GScreen(vehicle_data)));
      } else {
        setState(() {});
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
            Text("Charging Mode : ${data['charge_mode']}"),
            Text("Tc : ${data['tc']}"),
            Text("soc : ${data['soc']}"),
            Text(
                "Start At : ${data['StartAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(data['StartAt'])}"),
            Text(
                "Pause At : ${data['PauseAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(data['PauseAt'])}"),
            Text(
                "Peak Start At : ${data['PeakStartAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(data['PeakStartAt'])}"),
            Text(
                "End At : ${data['EndAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(data['EndAt'])}"),
          ],
        ),
      ),
    );
  }
}
