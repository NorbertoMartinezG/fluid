import 'dart:ffi';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors; // Colors esta definida tanto en libreria material como en Vector

// SPH fluid
main() {
  runApp(new MaterialApp(
    home: new DemoPage(),
  ));
}

class DemoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    return new Scaffold(
      body: new DemoBody(
        screenSize: MediaQuery.of(context).size,
      ),
    );
  }
}

class DemoBody extends StatefulWidget {
  final Size screenSize;

  DemoBody({Key key, @required this.screenSize}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return new _DemoBodyState();
  }
}

// void dambreak(){
//   valorPosicion[];
// }

class _DemoBodyState extends State<DemoBody> with TickerProviderStateMixin {
  AnimationController animationController;
  final nodeList = <Node>[];
  final numNodes = 150;

  @override
  void initState() {
    super.initState();

    double REST_DENS = 1000.0; // densidad en reposo
    double GAS_CONST = 2000.0; // const for equation of state
    double H = 16.0; // kernel radius
    double HSQ = H * H; // radius^2 for optimization
    double MASS = 65.0; // assume all particles have the same mass
    double VISC = 250.0; // viscosity constant
    double DT = 0.00080; // integration timestep

// smoothing kernels defined in Müller and their gradients
    double POLY6 = 315.0 / (65.0 * 3.1416 * pow(H, 9.0)); // El núcleo poly6 también se conoce como núcleo polinomial de sexto grado. 
    double SPIKY_GRAD = -45.0 / (3.1416 * pow(H, 6.0)); // El gradiente del núcleo spiky se usa para calcular la fuerza de presión
    double VISC_LAP = 45.0 / (3.1416 * pow(H, 6.0)); // El Laplaciano de este núcleo (viscosity) se usa para calcular la fuerza de viscosidad 

// simulation parameters
    double EPS = H; // boundary epsilon
    double BOUND_DAMPING = -0.5; // amortiguacion 
    Offset G = Offset(0.0, 12000 * 9.8);

    
    
    //Array 2d Dart 
    //int row = numNodes;
    //int col = 2;
    //var twoDList = List.generate(row, (i) => List(col), growable: false);
    var listaxy = [];
    //var listay = [];
    //For fill;
    //twoDList[0][1] = "deneme";
    //print(twoDList); [[null, deneme], [null, null], [null, null], [null, null], [null, null]
    //int xx = 0;
    //int yy = 0;
    
    for (var y = EPS ; y < widget.screenSize.height - EPS * 2.0; y += H) {
      Random random = new Random(); //nextDouble () genera un valor de punto flotante aleatorio distribuido entre 0.0 y 1.0. Aquí hay una pequeña función para simular un lanzamiento
      for (var x = widget.screenSize.width / 4.0; x <= widget.screenSize.width / 2; x += H + 0.001*random.nextDouble()){
         //twoDList.insert([xx][yy], [x,y]);          
          listaxy.add([x,y]);
          //listay.add(y);
          //print(y);
          //print(listaxy);
          //print("salto-----------------------------------------");
          //yy +=1;
        }
       // xx += 1;  
      }
     //print(listaxy[0]); // [102.85714285714286, 16.0]
      //ejemplo array
      //twoDList[0][1] = "deneme";
      //print(twoDList); [[null, deneme], [null, null], [null, null], [null, null], [null, null]
  
    
    Iterable.generate(numNodes).forEach((i) { // inicializacion de particulas
      
      double valx = (listaxy[i][0]); // variable para posicion inicial en x
      double valy = (listaxy[i][1]); // variable para posicion inicial en y

      // if (i < 10 - 0.00005 * widget.screenSize.width) { // ciclo para acomodar solo 30 particulas
      //   valx = 100 + (1 + i * 15.0);
      //   valy = 150.0;
      // } else if(i < 20){
      //   valx = 100 + ((i - 10) * 15.0);
      //   valy = 250.0;
      // }else{
      //   valx = 100 + ((i - 20) * 15.0);
      //   valy = 350.0;
      // }

      nodeList.add( // inicializacion de valores no inicializados en la calse Node
        new Node(
          id: i, 
          screenSize: widget.screenSize, 
          position: Offset(valx, valy),
          viscosidad: Offset(1.0, 1.0),
          densidad: 0.0,
          velocidad: Offset(0.0, 0.0)
          )
        );
      } 
    );

    //ComputeDensityPressure
    //Vector2 positi = new Vector2(1.0,1.0);
    

    animationController = new AnimationController(
        vsync: this, duration: new Duration(seconds: 10))
      ..addListener(() {
        // ComputeDensityPressure --------------------------------------------------
        for (int x = 0; x < nodeList.length; x++) {
          //nodeList[x].move();
          nodeList[x].densidad = 0.0;
          for (int j = 0; j < nodeList.length; j++) {
            Offset rij = nodeList[j].position - nodeList[x].position ;
            double r2 = pow(rij.dx, 2) + pow(rij.dy, 2);
            if (r2 < HSQ) {
              nodeList[x].densidad += MASS * POLY6 * pow(HSQ - r2, 3);
            }

          }
          nodeList[x].presion = GAS_CONST * (nodeList[x].densidad - REST_DENS);
          //print(nodeList[x].presion);
          // for (int y = x + 1; y < nodeList.length; y++) {
          //   nodeList[x].connect(nodeList[y]);
          // }
        }
        // ComputeDensityPressure --------------------------------------------------
        // ComputeForces -----------------------------------------------------------
         for (int x = 0; x < nodeList.length; x++) {
           Vector2 fpress = new Vector2(0.0,0.0);
           //Vector2 fvisc = new Vector2(0.0,0.0);
           Offset fvisc = Offset(0, 0);
           Offset fpress2 = Offset(0.0, 0.0);


           for (int j = 0; j < nodeList.length; j++){
             //if (nodeList[x].direction == nodeList[j].direction) {continue;} // si la particula esta en la misma posicion, entonces se trata de ella misma y se salta
             Offset rij = nodeList[j].position - nodeList[x].position ;
             Vector2 rij2 = new Vector2(0.0,0.0); // vector para llevar los valores de "offset rij" a vector2 rij2 esto para usar metodos para vector
             rij2[0] = rij.dx; // asignacion de valores rij a rij2 X
             rij2[1] = rij.dy; // asignacion de valores rij a rij2 Y
             /*Vector methods
              normalize() → double
                  Normalizes this.
              normalized() → Vector3
                  Normalizes copy of this.
              normalizeInto(Vector3 out) → Vector3
                  Normalize vector into out.
             */
             double r = rij2.normalize(); // norm en eigen c++
             if (r < H) {

                // compute pressure force contribution de cada particula vecina
                // normalizar un vector es tomar un vector de cualquier longitud y, mientras sigue apuntando en la misma dirección, cambiar su longitud a 1, convirtiéndolo en lo que se conoce como un vector unitario.
                // normalized() Normaliza un vector conocido en tiempo de compilación  Devuelve lo anterior como una copia construida, no afecta a la clase. Puede usarlo para asignar - Vector normCopy = vect.normalized().

                fpress += -(rij2.normalized()) * MASS * (nodeList[x].presion + nodeList[j].presion) / (2.0 * nodeList[j].densidad) * SPIKY_GRAD * pow(H - r, 2.0); 
                //fpress += (rij2.normalized())* -1 * MASS * (nodeList[x].presion + nodeList[j].presion) / (2.0 * nodeList[j].densidad) * SPIKY_GRAD * pow(H - r, 2.0); 
                fpress2 = Offset(fpress[0],fpress[1]); // tomar valores de (fpress vector2) para (fpress2 offset)
                // compute viscosity force contribution
                fvisc += ((nodeList[j].velocidad - nodeList[x].velocidad)/nodeList[j].densidad)* VISC * MASS * VISC_LAP * (H - r); // variable offset 
                //print(fvisc);
             }
           }
            Offset fgrav = G * nodeList[x].densidad;
            nodeList[x].fuerzas = fgrav + fvisc + fpress2;
            //print(nodeList[x].fuerzas);
            //print("funciona");
           
            // COLOR DE PARTICULA SEGUN LA FUERZA EN CADA UNA DE ELLAS
            double fuerzaTotal = nodeList[x].fuerzas.dx + nodeList[x].fuerzas.dy ;
            double colorDinamico2 = fuerzaTotal/10;
            int colorDinamico3 = colorDinamico2.toInt(); 
            int colorDinamico4 = colorDinamico3.abs();
            nodeList[x].notePaint.color=Color.fromARGB(255, colorDinamico4, 0, 150); // color dinamico segun fuerza
         }
        // ComputeForces -----------------------------------------------------------
        // Integracion -------------------------------------------------------------
        for (int x = 0; x < nodeList.length; x++) {
          		// forward Euler integration // DT = 0.0008f; // integration timestep
              //p.v += DT * p.f / p.rho; // Vt+1 = Vt + Δt * (Ftot/rho) // nueva velocidad
              nodeList[x].velocidad += ((nodeList[x].fuerzas)/nodeList[x].densidad) * DT;
              //p.x += DT * p.v;		// Vt+1 = xt + Δt * Vt+1		// nueva posicion
              nodeList[x].position += (nodeList[x].velocidad) * DT;
              // enforce boundary conditions // imponer condiciones de contorno
              // EPS = H; // boundary epsilon
              // ANALISIS DE NUEVAS POSICIONES EN BASE A LOS LIMITES
              // analisis de posicion 0 en vector2d x
              //posicionamiento en X global de la simulacion o ventana de simulacion
              // EPS = H
              if (nodeList[x].position.dx - EPS < 0.0) // si la posicion de la particula en el eje x menos H o es menor a 0(inicio del espacio de simulacion)  entonces:
              {
                //p.v(0) *= BOUND_DAMPING; //BOUND_DAMPING = -0.5f; coeficiente de amortiguamiento, desaceleracion por -0.5 que cambia la direccion de la velocidad
                double mod_velx = 1.0;
                mod_velx *= (nodeList[x].velocidad.dx)*BOUND_DAMPING;
                nodeList[x].velocidad = Offset(mod_velx, nodeList[x].velocidad.dy);
                //p.x(0) = EPS; // coloca la particula al inicio del ancho de la simulacion mas H.
                double mod_posx = EPS;
                nodeList[x].position = Offset(mod_posx, nodeList[x].position.dy);
                //nodeList[x].position.dx = EPS; NO SE PUEDE HACER DIRECTO EL CAMBIO YA QUE OFFSET no se puede modificar directamente en su parametro dx
              }
              //posicionamiento en X global de la simulacion o ventana de simulacion
		          // EPS = H
              //if (p.x(0) + EPS > VIEW_WIDTH) // // si la posicion en el eje x de la particula mas H o es mayor al ancho de la simulacion entonces:
              if (nodeList[x].position.dx + EPS > widget.screenSize.width ) // // si la posicion en el eje x de la particula mas H o es mayor al ancho de la simulacion entonces:
              {
                //p.v(0) *= BOUND_DAMPING; // desaceleracion por -0.5 que cambia la direccion de la velocidad
                double mod_velx = 1.0;
                mod_velx *= (nodeList[x].velocidad.dx)*BOUND_DAMPING;
                nodeList[x].velocidad = Offset(mod_velx, nodeList[x].velocidad.dy);
                //p.x(0) = VIEW_WIDTH - EPS; //coloca a la particula al borde del ancho de la simulacion con una distancia H
                double mod_posx = widget.screenSize.width - EPS;
                nodeList[x].position = Offset(mod_posx, nodeList[x].position.dy);
              }
              
              
              //posicionamiento en Y global de la simulacion o ventana de simulacion
              //if (p.x(1) - EPS < 0.0f) //detecta si la particula esta cercana al inicio o 0, si es asi:
              if (nodeList[x].position.dy - EPS < 0.0) // si la posicion de la particula en el eje y menos H o es menor a 0(inicio del espacio de simulacion)  entonces:
              {
                //p.v(1) *= BOUND_DAMPING; //invierte la velocidad por -0.5f
                double mod_vely = 1.0;
                mod_vely *= (nodeList[x].velocidad.dy) * BOUND_DAMPING;
                nodeList[x].velocidad = Offset(nodeList[x].velocidad.dx, mod_vely);
                
                //p.x(1) = EPS; // posiciona a la particula a una distancia EPS o H de su posicion en Y
                double mod_posY = EPS;
                nodeList[x].position = Offset(nodeList[x].position.dx, mod_posY);

              }
              //if (p.x(1) + EPS > VIEW_HEIGHT) //detecta si la particula ha llegado al limite superior de la ventana grafica si es asi:
              if (nodeList[x].position.dy + EPS > widget.screenSize.height ) // // si la posicion en el eje y de la particula mas H o es mayor al ancho de la simulacion entonces:
              {
                //p.v(1) *= BOUND_DAMPING; //Invierte velocidad y la multiplica por -0.5f a modo de freno
                double mod_velY = 1.0;
                mod_velY *= (nodeList[x].velocidad.dy)*BOUND_DAMPING;
                nodeList[x].velocidad = Offset(nodeList[x].velocidad.dx, mod_velY);
                              
                //p.x(1) = VIEW_HEIGHT - EPS;// posiciona a la particula a una distancia EPS o H del limite sup de la ventana grafica.
                double mod_posY = widget.screenSize.height - EPS;
                nodeList[x].position = Offset(nodeList[x].position.dx, mod_posY);

              }
        }


      }
    )
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      child: new AnimatedBuilder(
        animation: animationController,
        builder: (context, child) => new CustomPaint(
              size: widget.screenSize,
              painter: new _DemoPainter(widget.screenSize, nodeList),
            ),
      ),
    );
  }
}


class _DemoPainter extends CustomPainter {
  final List<Node> nodeList;
  final Size screenSize;
  var counter = 0;

  _DemoPainter(this.screenSize, this.nodeList);

  @override
  void paint(Canvas canvas, Size size) {
    for (var node in nodeList) {
      node.display(canvas);
    }
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) => true;
}

enum Direction {
  LEFT,
  RIGHT,
  TOP,
  BOTTOM,
  TOP_LEFT,
  TOP_RIGHT,
  BOTTOM_LEFT,
  BOTTOM_RIGHT
  }

class Node {
  int id;
  Size screenSize;
  double radius;
  double size;
  Offset position;
  Direction direction;
  Random random;
  Paint notePaint, linePaint;

  double densidad;
  double presion;
  Offset viscosidad;
  Offset fuerzas;
  Offset velocidad;

  //Map<int, Node> connected;

  Node(
      {@required this.id,
      this.size = 5.0,//Tamaño del punto 
      this.radius = 200.0,
      @required this.position,
      @required this.densidad,
      @required this.viscosidad,
      @required this.velocidad,
      @required this.screenSize}) {
    random = new Random();
    //connected = new Map();
    //position = screenSize.center(Offset.zero);
    //position = Offset(Random().nextDouble()*screenSize.width, Random().nextDouble()*screenSize.height); // posicion inicial
    //position = screenSize.center(Offset.zero);
    direction = Direction.values[random.nextInt(Direction.values.length)];

    notePaint = new Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;
    linePaint = new Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
  }

   void move() { // Integrar las funciones ComputeDensityPressure(); ComputeForces(); 	Integrate(); a position
     
   densidad = 0.0;
  
  
  //   switch (direction) {
  //     case Direction.LEFT:
  //       position -= new Offset(1.0, 0.0);
  //       if (position.dx <= 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.RIGHT,
  //           Direction.BOTTOM_RIGHT,
  //           Direction.TOP_RIGHT
  //         ];
  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }

  //       break;
  //     case Direction.RIGHT:
  //       position += new Offset(1.0, 0.0);
  //       if (position.dx >= screenSize.width - 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.LEFT,
  //           Direction.BOTTOM_LEFT,
  //           Direction.TOP_LEFT
  //         ];
  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.TOP:
  //       position -= new Offset(0.0, 1.0);
  //       if (position.dy <= 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.BOTTOM,
  //           Direction.BOTTOM_LEFT,
  //           Direction.BOTTOM_RIGHT
  //         ];
  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.BOTTOM:
  //       position += new Offset(0.0, 1.0);
  //       if (position.dy >= screenSize.height - 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.TOP,
  //           Direction.TOP_LEFT,
  //           Direction.TOP_RIGHT,
  //         ];
  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.TOP_LEFT:
  //       position -= new Offset(1.0, 1.0);
  //       if (position.dx <= 5.0 || position.dy <= 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.BOTTOM_RIGHT,
  //         ];

  //         //if y invalid and x valid
  //         if (position.dy <= 5.0 && position.dx > 5.0) {
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.BOTTOM_LEFT);
  //         }
  //         //if x invalid and y valid
  //         if (position.dx <= 5.0 && position.dy > 5.0) {
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.TOP_RIGHT);
  //         }

  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.TOP_RIGHT:
  //       position -= new Offset(-1.0, 1.0);
  //       if (position.dx >= screenSize.width - 5.0 || position.dy <= 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.BOTTOM_LEFT,
  //         ];

  //         //if y invalid and x valid
  //         if (position.dy <= 5.0 && position.dx < screenSize.width - 5.0) {
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.BOTTOM_RIGHT);
  //         }
  //         //if x invalid and y valid
  //         if (position.dx >= screenSize.width - 5.0 && position.dy > 5.0) {
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.TOP_LEFT);
  //         }

  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.BOTTOM_LEFT:
  //       position -= new Offset(1.0, -1.0);
  //       if (position.dx <= 5.0 || position.dy >= screenSize.height - 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.TOP_RIGHT,
  //         ];
  //         //if y invalid and x valid
  //         if (position.dy >= screenSize.height - 5.0 && position.dx > 5.0) {
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.TOP_LEFT);
  //         }
  //         //if x invalid and y valid
  //         if (position.dx <= 5.0 && position.dy < screenSize.height - 5.0) {
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.BOTTOM_RIGHT);
  //         }

  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //     case Direction.BOTTOM_RIGHT:
  //       position += new Offset(1.0, 1.0);
  //       if (position.dx >= screenSize.width - 5.0 ||
  //           position.dy >= screenSize.height - 5.0) {
  //         List<Direction> dirAvailableList = [
  //           Direction.TOP_LEFT,
  //         ];
  //         //if y invalid and x valid
  //         if (position.dy >= screenSize.height - 5.0 &&
  //             position.dx < screenSize.width - 5.0) {
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.RIGHT);
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.TOP_RIGHT);
  //         }
  //         //if x invalid and y valid
  //         if (position.dx >= screenSize.width - 5.0 &&
  //             position.dy < screenSize.height - 5.0) {
  //           dirAvailableList.add(Direction.TOP);
  //           dirAvailableList.add(Direction.BOTTOM);
  //           dirAvailableList.add(Direction.LEFT);
  //           dirAvailableList.add(Direction.BOTTOM_LEFT);
  //         }

  //         direction = dirAvailableList[random.nextInt(dirAvailableList.length)];
  //       }
  //       break;
  //   }
  }

  // bool canConnect(Node node) {
  //   double x = node.position.dx - position.dx;
  //   double y = node.position.dy - position.dy;
  //   double d = x * x + y * y;
  //   return d <= radius * radius;
  // }

  // void connect(Node node) {
  //   if (canConnect(node)) {
  //     if (!node.connected.containsKey(id)) {
  //       connected.putIfAbsent(node.id, () => node);
  //     }
  //   } else if (connected.containsKey(node.id)) {
  //     connected.remove(node.id);
  //   }
  // }

  void display(Canvas canvas) {
    canvas.drawCircle(position, size, notePaint);

   // connected.forEach((id, node) {
   //   canvas.drawLine(position, node.position, linePaint);
    //});
  }

  bool operator ==(o) => o is Node && o.id == id;
  int get hashCode => id;
}