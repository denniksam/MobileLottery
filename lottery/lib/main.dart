import 'package:flutter/material.dart';

bool __enableTap = true;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
final tiles = [
  "One", "Two", "Three", "Four", "Five", "Six"
];

class _MyHomePageState extends State<MyHomePage> {
  Key _refreshKey = UniqueKey();
  var cards = <RotCard>[] ;
  @override
  void initState() {
    super.initState();
    makeCards();
  }
  void makeCards() {
    tiles.shuffle() ;
    cards = List.generate( tiles.length, (index) =>
        RotCard(
            callback: onCardTapped,
            index: index,
            controller: CardController(),
            child: Center(child: Text(tiles[index])))) ;
  }

  void onCardTapped(int index) {
    ScaffoldMessenger.of(context).showSnackBar( SnackBar(
      content: Text('Ваш бонус ${tiles[index]} (індекс кнопки $index)'),
    ));
    for( var card in cards ) {
      card.controller.show() ;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _refreshKey ,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon( Icons.refresh, size: 30, ),
            tooltip: "Refresh",
            onPressed: () {
              __enableTap = true;
              makeCards() ;
              setState(() => _refreshKey = UniqueKey() ) ;
            },
          ), //Ico
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
                    child:  cards[1],
                  ),),
                ],
              )),
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
                    child:  cards[2],
                  )),
                  Container(
                    width: 2,
                    color: Colors.grey,
                  ),
                  Expanded(child: Container(
                    color: Colors.grey.shade50,
                    child:  cards[3],
                  )),
                ],
              )),
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
                    child:  cards[4],
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
                  Expanded(child: Container(
                    color: Colors.grey.shade50,
                    child:  cards[5],
                  )),
                ],
              ))
        ],
      )
    );
  }
}

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
          __enableTap = false ;
          widget.controller.show();
          setState((){isSelected = true;} );
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
        child: const Center(child: Text("?", style: TextStyle(fontSize: 24),),),),
      ),
    ],),);
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
