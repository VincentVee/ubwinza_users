import 'package:cloud_firestore/cloud_firestore.dart';
class FirebaseService { FirebaseService._(); static final I = FirebaseService._(); final db = FirebaseFirestore.instance; }
class UFirebaseService { UFirebaseService._(); static final I = UFirebaseService._(); final db = FirebaseFirestore.instance; }