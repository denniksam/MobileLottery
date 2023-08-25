import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http ;

const Color firmLogoLight = Color(0xFFE73F3E);
const Color firmLogoDark = Color(0xFFC1212D);
const Color firmLogoGray = Color(0xFF484848);

const String backendHost = "api.smartlab.com.ua" ;
const String backendPath = "actions.php" ;

const String appTitle = "Lottery" ;
const String appPageTitle = "Обери собі бонус" ;
const String enterOrderCode = "Введіть код" ;
const String networkErrorTitle = "Помилка мережі" ;
const String networkErrorMessage = "Немає зв'язку із сервером акцій. Перезапустіть застосунок пізніше" ;
const String codeUnconfirmedTitle = "Код не підтверджено" ;
const String codeUnconfirmedMessage = "Код введено неправильно або введений код не є учасником акції, або код вже брав участь в акції, або термін акції вичерпано." ;
const String emptyFieldMessage = "Поле не можна залишати порожним" ;
const String goButtonText = "Поїхали" ;
const String defaultErrorMessage = 'У програмі виникла позаштатна ситуація' ;


bool __enableTap = true;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: firmLogoLight),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: appPageTitle),
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
  final _orderCodeController = TextEditingController();
  final _httpClient = http.Client() ;
  Key _refreshKey = UniqueKey();
  var cards = <RotCard>[] ;
  String? _orderCode ;
  String _firstLineText = "" ;
  String _errorWidgetMessage = "" ;

  @override
  void initState() {
    super.initState();
    _restart() ;
  }

  Future<bool> _loadAction() async {
    var response = await _httpClient.get(
        Uri.https( backendHost, backendPath )
    ) ;
    String body = utf8.decode( response.bodyBytes ) ;
    if( kDebugMode ) {
      print( "initState: got [${response.statusCode}] $body" ) ;
    }
    if(response.statusCode != 200) {
      return Future.error( networkErrorMessage ) ;
    }
    else {
      __actionItems.clear() ;
      try {
        for (var item in jsonDecode(body)) {
          __actionItems.add(ActionItem.fromJson(item));
        }
        return true;
      }
      catch( ex ) {
        if( kDebugMode ) {
          print( "initState: jsonDecode $ex" ) ;
        }
        return false ;
      }
    }
  }

  void _restart() {
    _loadAction()
      .then(
        (success) {
          if( success ) {
            __enableTap = true;
            _orderCode = null;
            makeCards();
            if (mounted) {
              setState(() => _refreshKey = UniqueKey());
            }
          }
          else {
            if (mounted) {
              setState(() => _errorWidgetMessage = defaultErrorMessage);
            }
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorWidgetMessage = error.toString();
            });
            _showAlert(
                title: networkErrorTitle,
                message: _errorWidgetMessage
            );
          }
        }
      ) ;
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
        http.Request(
            "CHECK",
            Uri.https( backendHost, backendPath, { 'code': code } )
        )
    ) ;
    String body = utf8.decode(await streamedResponse.stream.toBytes());
    if (kDebugMode) {
      print("initState: got [${streamedResponse.statusCode}] $body");
    }
    if (streamedResponse.statusCode != 200) {
      if (mounted) {
        setState(() {
          _errorWidgetMessage = networkErrorMessage ;
        });
      }
      _showAlert(
          title: networkErrorTitle,
          message: _errorWidgetMessage
      );
    }
    else {
      var json = jsonDecode( body ) ;
      if( json['result'] ?? false ) {
        if (mounted) {
          setState(() {
            _orderCode = code ;
            _firstLineText = "Вибір бонусу по коду $code";
          });
        }
        _orderCodeController.clear();
      }
      else {
        if (mounted) {
          _showAlert(
              title: codeUnconfirmedTitle,
              message: codeUnconfirmedMessage
          );
        }
      }
    }
  }

  Future<void> _sendChoice(int index) async {
    var response = await _httpClient.put(
        Uri.https( backendHost, backendPath, {
              'code': _orderCode,
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
              "По коду $_orderCode вибран бонус ${__actionItems[index]
                  .code} (${__actionItems[index].name})",
              maxLen: 40);
        });
      }
    }
    else {
      if(mounted) {
        setState(() {
          _firstLineText = "По коду $_orderCode вибір НЕ ЗБЕРЕЖЕНО!" ;
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
          : _orderCode == null
          ? _orderDataWidget()
          : _lotteryWidget(),
    );
  }

  Widget _orderDataWidget() {
    return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              const Spacer(),
              Image.asset("assets/images/logo_with_text.png"),
              const Spacer(),
              const Text(enterOrderCode, style: TextStyle(fontSize: 18),),
              const Spacer(),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
                child: CodeInputField(onComplete: _onCodeEntered,),
              ),
              const Spacer(),
              /* ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(firmLogoDark)
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _onCodeEntered(_orderCodeController.text) ;
                  }
                },
                child: const Text(
                  goButtonText,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20
                  ),
                ),
              ),*/
              const Spacer(),
            ]);
  }

  Widget _lotteryWidget() {
    int rem = cards.length % 2 ;
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

        for(int i = 1; i < cards.length ~/ 2 + rem - 1; i += 1 )
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
                    child: cards[cards.length + rem - 2],
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
                    ))
                  else
                    Expanded(child: Container(
                      color: Colors.grey.shade100
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
            content: Text(message ?? defaultErrorMessage ),
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

// region //////////////// CODE ///////////////////////////////////////////

class CodeInputField extends StatefulWidget {
  final Function onComplete ;

  const CodeInputField({super.key, required this.onComplete});

  @override
  State<StatefulWidget> createState() => _CodeInputFieldState() ;
}

class _CodeInputFieldState extends State<CodeInputField> {
  static const digits = ['0','1','2','3','4','5','6','7','8','9'] ;
  final int cnt = 6 ;
  final _fields = <TextField>[] ;
  var _controllers = <TextEditingController>[] ;
  var _focusNodes = <FocusNode>[] ;
  var currentIndex = 0 ;

  @override
  void initState() {
    super.initState();
    ServicesBinding.instance.keyboard.addHandler(_onKey);
    _controllers = List.generate( cnt, (_) => TextEditingController() ) ;
    _focusNodes = List.generate( cnt, (_) => FocusNode() ) ;
    for(int i = 0; i < cnt; i += 1) {
      _fields.add(
        TextField(
          autofocus: i == 0,
          controller: _controllers[i],
          focusNode: _focusNodes[i],
          keyboardType: TextInputType.number,
          maxLength: 1,
          onTap: () => _fieldTapped(i),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24,),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderSide: BorderSide(width: 1)
            ),
            counterText: "",
          ),
        )
      ) ;
    }
  }

  void _fieldTapped(int index) {
    currentIndex = index ;
    _controllers[currentIndex].selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controllers[currentIndex].text.length
    ) ;
  }

  bool _onKey( KeyEvent event ) {  // https://stackoverflow.com/a/75736557/5569247
    if (event is KeyDownEvent) {
      final key = event.logicalKey.keyLabel;
      if (key == "Backspace") {
        _controllers[currentIndex].clear() ;
        if( currentIndex > 0 ) {
          currentIndex -= 1;
          _focusNodes[currentIndex].requestFocus();
          _controllers[currentIndex].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controllers[currentIndex].text.length
          ) ;
        }
      }
      else if( digits.contains( key ) ) {
          _controllers[currentIndex].text = key ;
          _trySubmit() ;
        }
    }
    return true;
  }

  void _trySubmit() {
    int emptyIndex = -1 ;
    for( int i = 0; i < cnt; i += 1) {
      int n = (currentIndex + i + 1) % cnt ;
      if( _controllers[n].text.isEmpty ) {
        emptyIndex = n ;
        break ;
      }
    }
    if( emptyIndex == -1 ) {
      widget.onComplete( _controllers.map((c) => c.text).join() ) ;
    }
    else {
      currentIndex = emptyIndex ;
      _focusNodes[currentIndex].requestFocus() ;
    }
  }

  Widget _fieldGenerator(index) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _fields[index],
      )
  ) ;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate( cnt ~/ 2, _fieldGenerator),
        const Text("\u2014", style: TextStyle(fontSize: 28),),
        ...List.generate( cnt - cnt ~/ 2, (i) => _fieldGenerator(cnt ~/ 2 + i)),
      ]
    ) ;
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKey);
    super.dispose();
  }
}
// endregion

// region //////////////// CARD ///////////////////////////////////////////

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
// endregion

// region /////////////// ORM //////////////////////////////////////////////
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
// endregion