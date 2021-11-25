//import 'dart:ffi';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors; // Colors esta definida tanto en libreria material como en Vector

import 'package:sensors_plus/sensors_plus.dart';

import 'package:flutter/services.dart'; // para evitar rotacion entre otros

// SPH fluid
main() {
  
  WidgetsFlutterBinding.ensureInitialized();// para evitar que gire la pantalla agregar libreria services
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])// para evitar que gire la pantalla agregar libreria services
    .then((_) {// para evitar que gire la pantalla agregar libreria services
      runApp(new MaterialApp(home: new DemoPage()));
      });

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


class _DemoBodyState extends State<DemoBody> with TickerProviderStateMixin {
  AnimationController animationController;
  final coleccionParticulas = <Particle>[];
  final numParticulas = 300;

  double gyroX = 0;
  double gyroY = 0;
  double gyroZ = 0;

  @override
  void initState() {
    super.initState();

    
      // Para interaccion con girospio, acelerometro, // ESTO SOLO FUNCIONA CUANDO SE SELECCIONA EL EMULADOR pixel 3 XL API 29
      gyroscopeEvents.listen((GyroscopeEvent event) { // agregar libreria sensor_plus.dart
      setState(() {

        gyroX = event.x;
        gyroY = event.y;
        gyroZ = event.z;
      });
    });
    
     
    
    double densidadReposo = 1000.0; // densidad en reposo
    double constanteGas = 2000.0; // const for equation of state
    double H = 8.0; // kernel radius
    double h2 = H * H; // radius^2 for optimization
    double masa = 65.0; // assume all particles have the same masa
    double viscosidad = 250.0; // viscosidadosity constant
    double dt = 0.00080; // integration timestep

// smoothing kernels defined in Müller and their gradients
    double nucleoPoly6 = 315.0 / (65.0 * 3.1416 * pow(H, 9.0)); // El núcleo nucleoPoly6 también se conoce como núcleo polinomial de sexto grado. 
    double gradienteSpiky = -45.0 / (3.1416 * pow(H, 6.0)); // El gradiente del núcleo spiky se usa para calcular la fuerza de presión
    double laplacianoViscosity = 45.0 / (3.1416 * pow(H, 6.0)); // El Laplaciano de este núcleo (viscosidadosity) se usa para calcular la fuerza de viscosidad 

// simulation parameters
    double limitePantalla = H; // boundary limitePantallailon
    double amortiguacion = -0.5; // amortiguacion 
    Offset G = Offset(0.0, 12000 * 9.8);

    
    
    
    var listaxy = [];
    
    for (var y = limitePantalla ; y < widget.screenSize.height - limitePantalla * 2.0; y += H) { // OPTIMIZAR -- YA QUE LEE TODA LA PANTALLA
      Random random = new Random(); //nextDouble () genera un valor de punto flotante aleatorio distribuido entre 0.0 y 1.0. Aquí hay una pequeña función para simular un lanzamiento
      for (var x = widget.screenSize.width / 4.0; x <= widget.screenSize.width / 2; x += H + 0.001*random.nextDouble()){
         
          listaxy.add([x,y]);
          
        }
        
      }
    
    
    Iterable.generate(numParticulas).forEach((i) { // inicializacion de particulas
      
      double valx = (listaxy[i][0]); // variable para posicion inicial en x
      double valy = (listaxy[i][1]); // variable para posicion inicial en y

      coleccionParticulas.add( // inicializacion de valores no inicializados en la calse Particle
        new Particle(
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

void move(){


          // Compute Density Pressure --------------------------------------------------
        for (int x = 0; x < coleccionParticulas.length; x++) 
        {

          //coleccionParticulas[x].move();
          coleccionParticulas[x].densidad = 0.0;
          for (int j = 0; j < coleccionParticulas.length; j++) {
            Offset rij = coleccionParticulas[j].position - coleccionParticulas[x].position ;
            double r2 = pow(rij.dx, 2) + pow(rij.dy, 2);
            if (r2 < h2) {
              coleccionParticulas[x].densidad += masa * nucleoPoly6 * pow(h2 - r2, 3);
            }

          }
          coleccionParticulas[x].presion = constanteGas * (coleccionParticulas[x].densidad - densidadReposo);
         
        }
        
        // ComputeForces -----------------------------------------------------------
         for (int x = 0; x < coleccionParticulas.length; x++) {
           Vector2 fpress = new Vector2(0.0,0.0);
           Offset fviscosidad = Offset(0, 0);
           Offset fpress2 = Offset(0.0, 0.0);


           for (int j = 0; j < coleccionParticulas.length; j++){
             
             Offset rij = coleccionParticulas[j].position - coleccionParticulas[x].position ;
             Vector2 rij2 = new Vector2(0.0,0.0); // vector para llevar los valores de "offset rij" a vector2 rij2 esto para usar metodos para vector
             rij2[0] = rij.dx; // asignacion de valores rij a rij2 X
             rij2[1] = rij.dy; // asignacion de valores rij a rij2 Y

             double r = rij2.normalize(); // norm en eigen c++
             if (r < H) {

                // compute pressure force contribution de cada particula vecina
                // normalizar un vector es tomar un vector de cualquier longitud y, mientras sigue apuntando en la misma dirección, cambiar su longitud a 1, convirtiéndolo en lo que se conoce como un vector unitario.
                // normalized() Normaliza un vector conocido en tiempo de compilación  Devuelve lo anterior como una copia construida, no afecta a la clase. Puede usarlo para asignar - Vector normCopy = vect.normalized().

                fpress += -(rij2.normalized()) * masa * (coleccionParticulas[x].presion + coleccionParticulas[j].presion) / (2.0 * coleccionParticulas[j].densidad) * gradienteSpiky * pow(H - r, 2.0); 
                
                fpress2 = Offset(fpress[0],fpress[1]); // tomar valores de (fpress vector2) para (fpress2 offset)
                
                fviscosidad += ((coleccionParticulas[j].velocidad - coleccionParticulas[x].velocidad)/coleccionParticulas[j].densidad)* viscosidad * masa * laplacianoViscosity * (H - r); // variable offset 
                
             }
           }
            // ESTO SOLO FUNCIONA CUANDO SE SELECCIONA EL EMULADOR pixel 3  XL API 29
            G = Offset(0.0, 12000 * 9.8 * (1 + (gyroX*3 + gyroY + gyroZ))); // gravedad 9.8 modificada temporalmente 
            
            Offset fgrav = G * coleccionParticulas[x].densidad; // original
            coleccionParticulas[x].fuerzas = fgrav + fviscosidad + fpress2;
           
            // COLOR DE PARTICULA SEGUN LA FUERZA EN CADA UNA DE ELLAS
            double fuerzaTotal = fpress2.dx + fpress2.dy ; // solo fuerza debida a presion.
            double colorDinamico2 = fuerzaTotal/1000;
            int colorDinamico3 = colorDinamico2.toInt(); 
            int colorDinamico4 = colorDinamico3.abs();
            coleccionParticulas[x].notePaint.color=Color.fromARGB(255, 0, colorDinamico4, 255); // color dinamico segun fuerza
         }
        
        // Integracion -------------------------------------------------------------
        for (int x = 0; x < coleccionParticulas.length; x++) {
              coleccionParticulas[x].velocidad += ((coleccionParticulas[x].fuerzas)/coleccionParticulas[x].densidad) * dt;
              coleccionParticulas[x].position += (coleccionParticulas[x].velocidad) * dt;

              if (coleccionParticulas[x].position.dx - limitePantalla < 0.0) // si la posicion de la particula en el eje x menos H o es menor a 0(inicio del espacio de simulacion)  entonces:
              {
                
                double modVelx = 1.0;
                modVelx *= (coleccionParticulas[x].velocidad.dx)*amortiguacion;
                coleccionParticulas[x].velocidad = Offset(modVelx, coleccionParticulas[x].velocidad.dy);
                
                double modPosx = limitePantalla;
                coleccionParticulas[x].position = Offset(modPosx, coleccionParticulas[x].position.dy);
                
              }
              //posicionamiento en X global de la simulacion o ventana de simulacion
		        
              if (coleccionParticulas[x].position.dx + limitePantalla > widget.screenSize.width ) // // si la posicion en el eje x de la particula mas H o es mayor al ancho de la simulacion entonces:
              {
               // desaceleracion por -0.5 que cambia la direccion de la velocidad
                double modVelx = 1.0;
                modVelx *= (coleccionParticulas[x].velocidad.dx)*amortiguacion;
                coleccionParticulas[x].velocidad = Offset(modVelx, coleccionParticulas[x].velocidad.dy);
                //coloca a la particula al borde del ancho de la simulacion con una distancia H
                double modPosx = widget.screenSize.width - limitePantalla;
                coleccionParticulas[x].position = Offset(modPosx, coleccionParticulas[x].position.dy);
              }
              
              
              //posicionamiento en Y global de la simulacion o ventana de simulacion

              if (coleccionParticulas[x].position.dy - limitePantalla < 0.0) // si la posicion de la particula en el eje y menos H o es menor a 0(inicio del espacio de simulacion)  entonces:
              {
                //invierte la velocidad por -0.5f
                double modVely = 1.0;
                modVely *= (coleccionParticulas[x].velocidad.dy) * amortiguacion;
                coleccionParticulas[x].velocidad = Offset(coleccionParticulas[x].velocidad.dx, modVely);
                
                // posiciona a la particula a una distancia limitePantalla o H de su posicion en Y
                double modPosY = limitePantalla;
                coleccionParticulas[x].position = Offset(coleccionParticulas[x].position.dx, modPosY);

              }
              //detecta si la particula ha llegado al limite superior de la ventana grafica si es asi:
              if (coleccionParticulas[x].position.dy + limitePantalla > widget.screenSize.height ) // // si la posicion en el eje y de la particula mas H o es mayor al ancho de la simulacion entonces:
              {
               //Invierte velocidad y la multiplica por -0.5f a modo de freno
                double modVely = 1.0;
                modVely *= (coleccionParticulas[x].velocidad.dy)*amortiguacion;
                coleccionParticulas[x].velocidad = Offset(coleccionParticulas[x].velocidad.dx, modVely);
                              
                // posiciona a la particula a una distancia limitePantalla o H del limite sup de la ventana grafica.
                double modPosY = widget.screenSize.height - limitePantalla;
                coleccionParticulas[x].position = Offset(coleccionParticulas[x].position.dx, modPosY);

              }
        }

       






}


    animationController = new AnimationController(
        vsync: this, duration: new Duration(seconds: 10))
      ..addListener(() {

          move();

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
              painter: new _DemoPainter(widget.screenSize, coleccionParticulas),
            ),
      ),
    );
  }
}


class _DemoPainter extends CustomPainter {
  final List<Particle> coleccionParticulas;
  final Size screenSize;
  var counter = 0;

  _DemoPainter(this.screenSize, this.coleccionParticulas);

  @override
  void paint(Canvas canvas, Size size) {
    for (var Particle in coleccionParticulas) {
      Particle.display(canvas);
    }
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) => true;
}



class Particle {
  int id;
  Size screenSize;
  double radius;
  double size;
  Offset position;
 
  Random random;
  Paint notePaint, linePaint;

  double densidad;
  double presion;
  Offset viscosidad;
  Offset fuerzas;
  Offset velocidad;

  //Map<int, Particle> connected;

  Particle(
      {@required this.id,
      this.size = 8.0,//Tamaño del punto 
      this.radius = 100.0,
      @required this.position,
      @required this.densidad,
      @required this.viscosidad,
      @required this.velocidad,
      @required this.screenSize}) {
    random = new Random(); 
   
    notePaint = new Paint()
      ..color = Colors.blue.shade50;
      //..strokeWidth = 3.0 // ancho del contorno del circulo relacionado con style
      //..maskFilter = MaskFilter.blur(BlurStyle.solid, 3.0) // desemfoque, QUITA RENDIMIENTO
      //..style = PaintingStyle.stroke; // circulo relleno o vacio
    
    linePaint = new Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
  }

  void display(Canvas canvas) {
    canvas.drawCircle(position, size, notePaint);
    

  }

  bool operator ==(o) => o is Particle && o.id == id;
  int get hashCode => id;
}

