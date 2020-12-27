import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:v2g_app/util/Resources.dart';
import 'package:v2g_app/charging.dart';
import 'package:v2g_app/v2g.dart';
import 'package:web_socket_channel/io.dart';
import 'package:v2g_app/service/api_service.dart';

void main() async {
  Resources.webSocet = IOWebSocketChannel.connect("ws://localhost:8181");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'V2G APP',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
      builder: EasyLoading.init(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<FormBuilderState> _fbKey = GlobalKey<FormBuilderState>();
  var data = Map();
  var _api_service = APIService();
  var t_in = DateTime.now();
  var t_out = DateTime.now();
  final _txtSOCController = TextEditingController();
  final _txtTinController = TextEditingController();

  setData(charge_mode, startAt, endAt, soc,
      {pauseAt = null, peakStartAt = null}) {
    data = Map();
    data['id'] = Resources.VEHICLE_ID;
    data['soc'] = soc;
    data['charge_mode'] = charge_mode;
    data['StartAt'] = startAt.toInt();
    data['EndAt'] = endAt.toInt();
    data['PauseAt'] = pauseAt == null ? null : pauseAt.toInt();
    data['PeakStartAt'] = peakStartAt == null ? null : peakStartAt.toInt();
  }

  getUserChargingConfig(context, soc, T_in, T_out) async {
    var soc_remain = 80 - soc;
    soc_remain = soc_remain * 40 / 100;
    var Tc = soc_remain / Resources.C_RATE;
    Tc = Tc * 3600000;
    var T1 = new DateTime(T_in.year, T_in.month, T_in.day, 5, 30)
        .millisecondsSinceEpoch;
    var T2 = new DateTime(T_in.year, T_in.month, T_in.day, 18, 30)
        .millisecondsSinceEpoch;
    var T3 = new DateTime(T_in.year, T_in.month, T_in.day, 22, 30)
        .millisecondsSinceEpoch;
    var T4 = new DateTime(T_in.year, T_in.month, T_in.day + 1, 5, 30)
        .millisecondsSinceEpoch;

    T_in = T_in.millisecondsSinceEpoch;
    T_out = T_out.millisecondsSinceEpoch;

//  0= yes, 1-no
    if (((T_in > T1) && (T_in < T2)) && ((T_out > T1) && (T_out < T2))) {
      // charging_mode=1;
      if (T_in + Tc > T_out) {
        // print("Normal Charge. Start at " + T_in + " and end in " + T_out);
        setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
      } else {
        //print("Normal Charge. Start at " + T_in + " and end in" + (T_in + Tc));
        setData(Resources.CHARGE_MODE_NORMAL, T_in, (T_in + Tc), soc);
      }
    } else if (((T_in > T1) && (T_in < T2)) && ((T_out > T2) && (T_out < T3))) {
      var deltaT = (T2 - T_in).abs();

      if (Tc >= deltaT) {
        // var eco_normal_reply = input('ask to Terminate in 18.5(T2)');

        var eco_normal_reply = await showOkCancelAlertDialog(
          context: context,
          title: "ask to Terminate in 18.5(T2)",
        );

        if (eco_normal_reply == OkCancelResult.cancel) {
          // %charging_mode=1;
          if (T_in + Tc > T_out) {
            //print("Normal Charge. Start at " + T_in + " and end in" + T_out);
            setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
          } else {
            //print("Normal Charge. Start at " +T_in + " and end in" + (T_in + Tc));

            setData(Resources.CHARGE_MODE_NORMAL, T_in, (T_in + Tc), soc);
          }
        } else {
          // %charging_mode=2;
          ////print("Eco Charge. Start at ${T_in} and end in $T2");
          setData(Resources.CHARGE_MODE_ECO, T_in, T2, soc);
        }
      } else {
        //  %charging_mode=1;
        if (T_in + Tc > T_out) {
          //print("Normal Charge. Start at ${T_in} and end in ${T_out}");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
        } else {
          //print("Normal Charge. Start at $T_in and end in ${T_in + Tc}");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, (T_in + Tc), soc);
        }
      }
    } else if (((T_in > T1) && (T_in < T2)) && ((T_out > T3) && (T_out < T4))) {
      var deltaT1 = (T2 - T_in).abs();
      var deltaT2 = (T_out - T3).abs();

      if (Tc <= (deltaT1 + deltaT2)) {
        // var ta = 0.0;
        if ((Tc - deltaT1) > 0) {
          setData(
            Resources.CHARGE_MODE_ECO,
            T_in,
            (T3 + (Tc - deltaT1)),
            soc,
            peakStartAt: T3,
            pauseAt: T2,
          );
        } else {
          setData(Resources.CHARGE_MODE_NORMAL, T_in, T_in + Tc, soc);
        }
      } else {
        var t_str = (Tc - ((deltaT1 + deltaT2))).abs();
      
        var ask_to_take_peak = await showOkCancelAlertDialog(
          context: context,
          title: "Need ${t_str / 60000} minutes. Ask to take peak?",
        );

        if (ask_to_take_peak == OkCancelResult.ok) {
          print("Start at $T_in,end 1st Slot at $T2. Charged Hours $deltaT1");
          print(
              "charged in peak. $t_str hours charge in peak. Charging start at ${(T3 - t_str)}");
          print(
              "Start at $T3,end 2st Slot at $T_out. Charged Hours ${deltaT2}");

          setData(
            Resources.CHARGE_MODE_ECO,
            T_in,
            T_out,
            soc,
            peakStartAt: (T3 - t_str),
            pauseAt: T2,
          );
        } else {
          print("Only Fill ${(deltaT1 + deltaT2)}. Not charge in peak");
          setData(
            Resources.CHARGE_MODE_ECO,
            T_in,
            T_out,
            soc,
            peakStartAt: T3,
            pauseAt: T2,
          );
        }
      }
    } else if (((T_in > T2) && (T_in < T3)) && ((T_out > T2) && (T_out < T3))) {
      if (T_in + Tc > T_out) {
        //print("Normal Charge. Start at $T_in and end in $T_out");
        setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
      } else {
        //print("Normal Charge. Start at $T_in and end in ${T_in + Tc}");
        setData(Resources.CHARGE_MODE_NORMAL, T_in, (T_in + Tc), soc);
      }
      // %charging_mode=1;
    } else if (((T_in > T2) && (T_in < T3)) && ((T_out > T3) && (T_out < T4))) {
      var deltaT1 = (T3 - T_in).abs();
      var deltaT2 = (T_out - T3).abs();
      if (Tc >= (deltaT1 + deltaT2)) {
        if (T_in + Tc > T_out) {
          //print("Normal Charge. Start at $T_in and end in $T_out");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
        } else {
          //print("Normal Charge. Start at $T_in and end in ${T_in + Tc}");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, (T_in + Tc), soc);
        }
        // %charging_mode=1;
      } else if (Tc > deltaT2) {
        var tp = (T_out - Tc);
        var ask_to_eco = await showOkCancelAlertDialog(
          context: context,
          title: "ask to eco charge at $tp?",
        );
        //print(ask_to_eco);
        if (ask_to_eco == OkCancelResult.ok) {
          //print("Eco Charge start at $tp. end at $T_out");
          setData(Resources.CHARGE_MODE_ECO, tp, T_out, soc);
        } else {
          if ((T4 - deltaT2) > T_out) {
            //print("Budget Charge. Start at $T3 and end in $T_out");
            setData(Resources.CHARGE_MODE_BUDGET, T3, T_out, soc);
          } else {
            //print("Budget Charge. Start at $T3 and end in ${(T4 - deltaT2)}");
            setData(Resources.CHARGE_MODE_BUDGET, T3, (T4 - deltaT2), soc);
          }
        }

        // %charging_mode=2;
      } else {
        // %charging_mode=3;
        //print("Budget Charge. Start at $T3 and end in ${(T4 - deltaT2)}");
        setData(Resources.CHARGE_MODE_BUDGET, T3, (T4 - deltaT2), soc);
      }
    } else if (((T_in > T3) && (T_in < T4)) && ((T_out > T3) && (T_out < T4))) {
      if (T_in + Tc > T_out) {
        //print("Budget Charge. Start at $T_in and end in $T_out");
        setData(Resources.CHARGE_MODE_BUDGET, T_in, T_out, soc);
      } else {
        //print("Budget Charge. Start at $T_in and end in ${T_in + Tc}");
        setData(Resources.CHARGE_MODE_BUDGET, T_in, T_in + Tc, soc);
      }
      //  %charging_mode=3;
    } else {
      var deltaT1 = (T1 - T_in).abs();
      var deltaT2 = (T_out - T1).abs();
      if (Tc >= (deltaT1 + deltaT2)) {
        //  %charging_mode=1;
        if (T_in + Tc > T_out) {
          //print("Normal Charge. Start at $T_in and end in $T_out");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, T_out, soc);
        } else {
          //print("Normal Charge. Start at $T_in and end in ${T_in + Tc}");
          setData(Resources.CHARGE_MODE_NORMAL, T_in, T_in + Tc, soc);
        }
      } else if (Tc < deltaT1) {
        //print("Budget Charge. Start at $T_in and end in ${(T_in + Tc)}");
        setData(Resources.CHARGE_MODE_BUDGET, T_in, T_in + Tc, soc);
        //  %charging_mode=3;
      } else {
        // var eco_normal_reply = input('ask to Terminate in 5.5(T1)');
        var eco_normal_reply = await showOkCancelAlertDialog(
          context: context,
          title: "ask to Terminate in 5.5(T1)",
        );

        if (eco_normal_reply == OkCancelResult.cancel) {
          //print("Eco Charge. Start at $T_in and end in ${(T_in + Tc)}");
          setData(Resources.CHARGE_MODE_ECO, T_in, (T_in + Tc), soc);
        } else {
          //print("Budget Charge. Start at $T_in and end in $T1");
          setData(Resources.CHARGE_MODE_BUDGET, T_in, (T1), soc);
        }
        //  %charging_mode=2;
      }
    }

    data['tc'] = Tc / 60000;
  }

  getVehicleDetails() async {
    EasyLoading.show(status: 'loading...');
    var vehicle = await _api_service.getVehicle(Resources.VEHICLE_ID);

    // print(vehicle);
    if (vehicle != null) {
      var vehicle_data = Map();
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
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => vehicle_data['isV2G']
                  ? V2GScreen(vehicle_data)
                  : ChargingScreen(vehicle_data)));
    }

    EasyLoading.dismiss();
  }

  @override
  void initState() {
    getVehicleDetails();
  }

  @override
  Widget build(BuildContext context) {
    double sysHeight = MediaQuery.of(context).size.height;
    double sysWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(),
      body: Container(
          child: Column(
        children: [
          TextFormField(
            controller: _txtSOCController,
            decoration: InputDecoration(labelText: 'SOC'),
            keyboardType: TextInputType.number,
          ),
          FormBuilderDateTimePicker(
            controller: _txtTinController,
            attribute: 'date',
            onChanged: (value) {
              setState(() {
                t_in = value;
              });
            },
            inputType: InputType.both,
            decoration: const InputDecoration(
              labelText: 'T IN',
            ),
            // locale: Locale('ru'),
            initialValue: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now(),
          ),
          FormBuilderDateTimePicker(
            attribute: 'date',
            onChanged: (value) {
              setState(() {
                t_out = value;
              });
            },
            inputType: InputType.both,
            decoration: const InputDecoration(
              labelText: 'T OUT',
            ),
            // locale: Locale('ru'),
            initialValue: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(new Duration(days: 1)),
          ),
          RaisedButton(
            child: Text("ENTER"),
            onPressed: () async {
              //  double.parse(_txtSOCController.text), t_in, t_out
              var currDate = DateTime.now();
              var soc = double.parse(_txtSOCController.text);
              var canV2G = soc > 40 &&
                  t_in.compareTo(
                          DateTime(t_in.year, t_in.month, t_in.day, 22, 00)) ==
                      -1 &&
                  t_out.compareTo(DateTime(
                          t_in.year, t_in.month, t_in.day + 1, 2, 00)) ==
                      1 &&
                  (soc - 40) * 0.4 / 0.75 > 1 &&
                  currDate.compareTo(
                          DateTime(t_in.year, t_in.month, t_in.day, 22, 30)) ==
                      -1;

              // var canV2G = false;
              var asktoV2G = OkCancelResult.cancel;
              if (canV2G) {
                asktoV2G = await showOkCancelAlertDialog(
                  context: context,
                  title: "Can use V2G. Enable?",
                );
              }
              if (asktoV2G == OkCancelResult.ok) {
                setState(() {
                  data['isV2G'] = true;
                  data['isCharging'] = false;
                  data['soc'] = soc;
                  data['mode'] = Resources.MODE_V2G;
                  data['id'] = Resources.VEHICLE_ID;
                });
              } else {
                await getUserChargingConfig(
                    context, double.parse(_txtSOCController.text), t_in, t_out);

                setState(() {
                  data['isV2G'] = false;
                  data['isCharging'] = true;
                  data['mode'] = Resources.MODE_CHARGING;
                });
              }
              EasyLoading.show(status: 'loading...');
              var resp = await _api_service.addNode(data);
              EasyLoading.dismiss();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => data['isV2G']
                          ? V2GScreen(data)
                          : ChargingScreen(data)));
            },
          ),
        ],
      )),
    );
  }
}
