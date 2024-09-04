import 'package:ble_sensor_app/database_services.dart';
import 'subject.dart';

DatabaseServices db = DatabaseServices();

bool subjectSelected = false;

Subject subject = Subject(
  id: -1,
  sex: 'M',
  birthday: '01/01/2000',
  weight: 150.0,
  height: 72.0,
  notes: 'This is a placeholder subject',
);
