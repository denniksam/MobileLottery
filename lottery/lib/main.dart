import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http ;

const Color firmLogoLight = Color(0xFFE73F3E);
const Color firmLogoDark = Color(0xFFC1212D);
const Color firmLogoGray = Color(0xFF484848);

bool __enableTap = true;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: firmLogoLight),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Обери собі бонус'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

var __actionItems = <ActionItem>[] ;

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _orderLastDigitsController = TextEditingController();
  final _httpClient = http.Client() ;
  Key _refreshKey = UniqueKey();
  var cards = <RotCard>[] ;
  String? _orderLastDigits ;
  String _firstLineText = "" ;
  String _errorWidgetMessage = "" ;

  @override
  void initState() {
    super.initState();
    _httpClient.get(Uri.https("api.smartlab.com.ua","actions.php"))
    .then((response) {
      String body = utf8.decode( response.bodyBytes ) ;
      if( kDebugMode ) {
        print( "initState: got [${response.statusCode}] $body" ) ;
      }
      if(response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _errorWidgetMessage =
            "Немає зв'язку із сервером акцій. Перезапустіть застосунок пізніше";
          });
        }
        _showAlert(
            title: "Помилка мережі",
            message: _errorWidgetMessage
        );
      }
      else {
        for( var item in jsonDecode( body ) ) {
          __actionItems.add( ActionItem.fromJson( item ) ) ;
        }
        _restart() ;
      }
    });
  }

  void _restart() {
    __enableTap = true;
    _orderLastDigits = null;
    makeCards();
    setState( () => _refreshKey = UniqueKey() ) ;
  }

  void makeCards() {
    __actionItems.shuffle() ;
    cards = List.generate( __actionItems.length, (index) =>
        RotCard(
            callback: onCardTapped,
            index: index,
            controller: CardController(),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Text(
                "${__actionItems[index].code}\n${__actionItems[index].name}",
                textAlign: TextAlign.center,
              )
            )
        ),
    ) ;
  }

  void onCardTapped(int index) {
    for( var card in cards ) {
      card.controller.show() ;
    }
    _sendChoice(index) ;
  }

  void _onCodeEntered(String code) async {
    var streamedResponse = await _httpClient.send(
        http.Request("CHECK",
            Uri.https(
              "api.smartlab.com.ua",
              "actions.php",
              { 'code': code }
            )
        )
    ) ;
    String body = utf8.decode(await streamedResponse.stream.toBytes());
    if (kDebugMode) {
      print("initState: got [${streamedResponse.statusCode}] $body");
    }
    if (streamedResponse.statusCode != 200) {
      if (mounted) {
        setState(() {
          _errorWidgetMessage =
          "Немає зв'язку із сервером акцій. Перезапустіть застосунок пізніше.";
        });
      }
      _showAlert(
          title: "Помилка мережі",
          message: _errorWidgetMessage
      );
    }
    else {
      var json = jsonDecode( body ) ;
      if( json['result'] ?? false ) {
        if (mounted) {
          setState(() {
            _orderLastDigits = code ;
            _firstLineText = "Вибір бонусу по коду $code";
          });
        }
        _orderLastDigitsController.clear();
      }
      else {
        if (mounted) {
          _showAlert(
              title: "Код не підтверджено",
              message: "Код введено неправильно або введений код не є учасником акції, або код вже брав участь в акції, або термін акції вичерпано."
          );
        }
      }
    }
  }

  Future<void> _sendChoice(int index) async {
    var response = await _httpClient.put(
        Uri.https(
            "api.smartlab.com.ua",
            "actions.php",
            {
              'code': _orderLastDigits,
              'choice': __actionItems[index].id
            }
        )
    ) ;
    String body = utf8.decode(response.bodyBytes);
    if (kDebugMode) {
      print("initState: got [${response.statusCode}] $body");
    }
    var json = jsonDecode( body ) ;
    if( json['result'] ?? false ) {
      if(mounted) {
        setState(() {
          _firstLineText = _ellipsis(
              "По коду $_orderLastDigits вибран бонус ${__actionItems[index]
                  .code} (${__actionItems[index].name})",
              maxLen: 40);
        });
      }
    }
    else {
      if(mounted) {
        setState(() {
          _firstLineText = "По коду $_orderLastDigits вибір НЕ ЗБЕРЕЖЕНО" ;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _refreshKey,
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30,),
            tooltip: "Refresh",
            onPressed: _restart,
          ),
        ],
      ),
      body: __actionItems.isEmpty
          ? _errorWidget()
          : _orderLastDigits == null
          ? _orderDataWidget()
          : _lotteryWidget(),
    );
  }

  Widget _orderDataWidget() {
    return Center(
      child: Form(
        key: _formKey,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              const Spacer(),
              Image.asset("assets/images/logo_with_text.png"),
              const Spacer(),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextFormField(
                  autofocus: true,
                  controller: _orderLastDigitsController,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.zero,
                    border: UnderlineInputBorder(),
                    label: Center( child: Text("Останні цифри замовлення")),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 30),
                  textAlign: TextAlign.center,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Поле не можна залишати порожним";
                    }
                    return null;
                  },
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(firmLogoDark)
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _onCodeEntered(_orderLastDigitsController.text) ;
                  }
                },
                child: const Text(
                  "Поїхали",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20
                  ),
                ),
              ),
              const Spacer(),
            ]),
      ),
    );
  }

  Widget _lotteryWidget() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_firstLineText),
        if(cards.length >= 2)
          Expanded(
              flex: 1,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Container(
                    color: Colors.grey.shade50,
                    child: cards[0],
                  )),
                  Container(
                    width: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.grey]
                      ),
                    ),
                  ),
                  Expanded(child: Container(
                    color: Colors.grey.shade50,
                    child: cards[1],
                  ),),
                ],
              )),

        for(int i = 1; i < cards.length ~/ 2 - 1; i += 1 )
          ...[
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.grey, Colors.white]
                ),
              ),
            ),
            Expanded(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Container(
                      color: Colors.grey.shade50,
                      child: cards[2 * i],
                    )),
                    Container(
                      width: 2,
                      color: Colors.grey,
                    ),
                    Expanded(child: Container(
                      color: Colors.grey.shade50,
                      child: cards[2 * i + 1],
                    )),
                  ],
                )),
          ],
        if(cards.length > 2) ...[
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.grey, Colors.white]
              ),
            ),
          ),
          Expanded(
              flex: 1,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Container(
                    color: Colors.grey.shade50,
                    child: cards[cards.length - 2 + cards.length % 2],
                  )),
                  Container(
                    width: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.grey, Colors.white]
                      ),
                    ),
                  ),
                  if(cards.length % 2 == 0)
                    Expanded(child: Container(
                      color: Colors.grey.shade50,
                      child: cards[cards.length - 1],
                    )),
                ],
              )),
        ],
      ],
    );
  }

  Widget _errorWidget() {
    return Center(
        child: Text(
          _errorWidgetMessage,
          textAlign: TextAlign.center,
        )
    ) ;
  }

  void _showAlert( { String? title, String? message } ) {
    if(mounted) {
      showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title ?? 'Повідомлення'),
            content: Text(message ?? 'У програмі виникла позаштатна ситуація'),
            actions: [
              TextButton(
                child: const Text("Зрозуміло"),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          )
      ) ;
    }
  }

  String _ellipsis( String str, {int? maxLen} ) {
    maxLen ??= 30 ;
    return str.length > maxLen
        ? '${str.substring(0, maxLen)}...'
        : str ;
  }

  @override
  void dispose() {
    super.dispose() ;
    _httpClient.close() ;
  }
}

////////////////// CARD ///////////////////////////////////////////

class RotCard extends StatefulWidget {
  const RotCard({super.key, required this.callback, required this.child, required this.index, required this.controller});
  final Widget child ;
  final int index ;
  final void Function(int) callback ;
  final CardController controller ;
  @override
  State<RotCard> createState() => _RotCardState();
}

class _RotCardState extends State<RotCard> {
  final Duration animDuration = const Duration(milliseconds: 400) ;
  final Duration openAllTimeout = const Duration(milliseconds: 800) ;
  bool isSelected = false ;
  @override
  initState() {
    super.initState();
    widget.controller.addListener(() => setState((){})) ;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (__enableTap) {
          __enableTap = false;
          widget.controller.show();
          setState(() {
            isSelected = true;
          });
          Future.delayed(openAllTimeout).then((value) =>
              widget.callback(widget.index));
        }
      },
      child: Stack(children: [
        Container(
            color: isSelected ? Colors.green.shade50 : Colors.transparent,
            child: widget.child
        ),
        AnimatedOpacity(
          opacity: widget.controller.isOpen ? 0.0 : 1.0,
          duration: animDuration,
          child: Container(color: Colors.white,
            child: Center(
              child: Image.asset("assets/images/logo_128t.png", scale: 2,),  // Text("?", style: TextStyle(fontSize: 24),),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class CardController extends ChangeNotifier {
  bool _isOpen;

  bool get isOpen => _isOpen;

  set isOpen(bool value) {
    _isOpen = value;
    notifyListeners();
  }

  double opacity = 1.0 ;

  CardController({bool? isOpen}) : _isOpen = isOpen ?? false;

  void show() {
    isOpen = true ;
  }

  void hide() {
    isOpen = false ;
  }

  void demo() {
    isOpen = false ;
    opacity = 0.5 ;
  }
}

///////////////// ORM //////////////////////////////////////////////
class ActionItem {
  final String code ;
  final String id ;
  final String name ;
  final String price ;
  final String? citoPrice ;
  
  ActionItem.fromJson( Map<String, dynamic> json ) :
    code = json['CODE'],
    id = json['ID'],
    name = json['NAME'],
    price = json['ACT_PRICE'],
    citoPrice = json['ACT_PRICE_CITO'] ;
}
/*
{
    "ID": "df9c230caf174b0e9d771df3a144eccc",
    "CODE": "1940",
    "NAME": "Батончик \"Смартлаб\"",
    "ACT_PRICE": "0.10",
    "ACT_PRICE_CITO": null
},
 */