import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_iap/payment_queue_delegate.dart';
import 'package:in_app_purchase_ios/in_app_purchase_ios.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

const _kSubscription1Id = 'com.ry-itto.example.subscription1';
const _kSubscription2Id = 'com.ry-itto.example.subscription2';
const _kProductIds = [
  _kSubscription1Id,
  _kSubscription2Id,
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  InAppPurchaseIosPlatform.registerPlatform();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Subscription Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _iosPlatform =
      InAppPurchasePlatform.instance as InAppPurchaseIosPlatform;
  final _iosPlatformAddition = InAppPurchasePlatformAddition.instance
      as InAppPurchaseIosPlatformAddition;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    _subscription = _iosPlatform.purchaseStream.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      // onDone: _subscription.cancel,
      onError: (error) {
        print(error);
      },
    );
    _iosPlatformAddition.setDelegate(PaymentQueueDelegate());
    initProducts();

    super.initState();
  }

  void initProducts() async {
    final productDetailResponse =
        await _iosPlatform.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null) {
      print(productDetailResponse.error!.code);
    }
    print(productDetailResponse.notFoundIDs);
    setState(() {
      _products = productDetailResponse.productDetails;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    print(purchaseDetailsList);
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print("pending...");
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print("error: ${purchaseDetails.error!}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          print(purchaseDetails.verificationData);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iosPlatform.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_products[index].title),
            trailing: Text(_products[index].price),
            onTap: () {
              _iosPlatform.buyNonConsumable(
                purchaseParam: PurchaseParam(
                  productDetails: _products[index],
                  applicationUserName: null,
                ),
              );
            },
          );
        },
        itemCount: _products.length,
      ),
    );
  }
}
