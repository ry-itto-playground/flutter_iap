import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'store_error.dart';

const _kSubscription1Id = 'com.ry-itto.example.subscription1';
const _kSubscription2Id = 'com.ry-itto.example.subscription2';
const _kProductIds = {
  _kSubscription1Id,
  _kSubscription2Id,
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  InAppPurchaseStoreKitPlatform.registerPlatform();
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
  final _iosPlatform = InAppPurchasePlatform.instance as InAppPurchaseStoreKitPlatform;
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
    initProducts();

    super.initState();
  }

  void initProducts() async {
    final isAvailable = await _iosPlatform.isAvailable();
    if (!isAvailable) {
      throw const StoreError(type: StoreErrorType.notAvailable);
    }
    final productDetailResponse = await _iosPlatform.queryProductDetails(_kProductIds);
    if (productDetailResponse.error != null) {
      throw StoreError.iapError(error: productDetailResponse.error);
    }
    if (productDetailResponse.notFoundIDs.isNotEmpty) {
      throw const StoreError(type: StoreErrorType.hasNotFoundId);
    }
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
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          print("pending...");
          break;
        case PurchaseStatus.purchased:
          // レシートの検証等
          print(purchaseDetails.verificationData);
          break;
        case PurchaseStatus.restored:
          final productId = purchaseDetails.productID;
          final product = _products.firstWhere((element) => element.id == productId);
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Restore'),
              content: Text(
                '${product.title} ${product.price} のサブスクリプションを Restore します',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () {
                    print('Restore 処理しました！！！');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
          break;
        case PurchaseStatus.error:
          // Error handling
          print("error: ${purchaseDetails.error!}");
          break;
        case PurchaseStatus.canceled:
          print('canceled!!');
          break;
      }

      if (purchaseDetails.status != PurchaseStatus.pending) {
        // completePurchase の呼び出しは必ずエラーハンドリングして、失敗した場合は可能ならリトライしないといけないかも
        // https://github.com/flutter/plugins/blob/fa036005b294e755f4c251e1b114f9212b4c1d21/packages/in_app_purchase/in_app_purchase/README.md#completing-a-purchase
        // > Warning: Failure to call InAppPurchase.completePurchase and get a successful response within 3 days of the purchase will result a refund.
        try {
          await _iosPlatform.completePurchase(purchaseDetails);
        } catch (error) {
          print(error);
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
      floatingActionButton: TextButton(
        onPressed: () {
          _iosPlatform.restorePurchases();
        },
        child: const Text('Restore'),
      ),
    );
  }
}
