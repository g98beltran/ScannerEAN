import SwiftUI
import CodeScanner
import Foundation
import AVFoundation

struct Respuesta: Codable {
    var id: String
    var name_es: String
    var reference: String
    var barCode: String?
    var internalPackBarcode: String
    var dun14: String
    var ean13: String?
}

struct ContentView: View {
    @State private var scannedCode: String?
    @State private var isShowingCodeView = false
    @State private var isFlashEnabled = true // Estado para el flash
    init() {
        // Activa el flash en la inicialización de la vista
        enableTorch()
    }

    var body: some View {
        VStack {
            if isShowingCodeView {
                CodeDisplayView(code: $scannedCode, isShowingCodeView: $isShowingCodeView)
            } else {
                CodeScannerView(codeTypes: [.code128, .code39, .ean8, .ean13], simulatedData: "pep") { response in
                    switch response {
                    case .success(let result):
                        scannedCode = result.string
                        isShowingCodeView = true
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
                // Botón para activar el flash
                Button(action: {
                    enableTorch() // Activa el flash al pulsar el botón
                }) {
                    Text("Encender Flash")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(Color.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    func checkFlashAvailability() -> Bool {
        if let device = AVCaptureDevice.default(for: AVMediaType.video) {
            return device.hasTorch && device.isTorchAvailable
        }
        return false
    }

    func enableTorch() {
        if checkFlashAvailability() {
            if let device = AVCaptureDevice.default(for: .video) {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .on
                    isFlashEnabled = true
                    // Configura la sesión para el modo de video continuo
                    let captureSession = AVCaptureSession()
                    captureSession.beginConfiguration()
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    captureSession.commitConfiguration()
                    device.unlockForConfiguration()
                } catch {
                    print("Error enabling torch: \(error.localizedDescription)")
                }
            }
        }
    }
    func disableTorch() {
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                isFlashEnabled = false // Marcar que el flash está apagado
                device.unlockForConfiguration()
            } catch {
                print("Error disabling torch: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CodeDisplayView: View {
    @Binding var code: String?
    @Binding var isShowingCodeView: Bool
    @State private var respuestaDelServidor: Respuesta?
    @State private var estaEsperandoRespuesta = false
    
    
    var body: some View {
        ZStack {Image("FotoStand2")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .opacity(0.5)
            VStack {
                if var code = $code.wrappedValue {
                    Text("Código escaneado: \(code)")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.pink)
                        .cornerRadius(10)
                    
                    // Mostrar el botón solo si no estamos esperando una respuesta
                    //if !estaEsperandoRespuesta {
                    Button("Enviar al servidor") {
                        if let codigoBarras = $code.wrappedValue {
                            enviarSolicitudAlServidor(conCodigoBarras: codigoBarras)
                            estaEsperandoRespuesta = true // Marcar que estamos esperando respuesta
                        } else {
                            print("El código de barras no es un String o es nulo.")
                        }
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                    //}
                    if let respuesta = respuestaDelServidor {
                        Text("ID: \(respuesta.id) \nNombre: \(respuesta.name_es) \nReferencia: \(respuesta.reference)")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .background(Color.black)
                            .cornerRadius(10)

//                        Text("ID: \(respuesta.id)")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                            .padding()
//                            .frame(minWidth: 0, maxWidth: .infinity)
//                            .background(Color.black)
//                            .cornerRadius(10)
//                        Text("Nombre: \(respuesta.name_es)")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                            .padding()
//                            .frame(minWidth: 0, maxWidth: .infinity)
//                            .background(Color.black)
//                            .cornerRadius(10)
//                        Text("Referencia: \(respuesta.reference)")
//                            .foregroundColor(.white)
//                            .font(.headline)
//                            .padding()
//                            .frame(minWidth: 0, maxWidth: .infinity)
//                            .background(Color.black)
//                            .cornerRadius(10)
                        // Y así sucesivamente para los demás campos
                    }
                    
                    Button("Escanear de nuevo") {
                        code = ""
                        isShowingCodeView = false
                    }
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.teal)
                    .cornerRadius(10)
                }
            }
        }
    }
    func enviarSolicitudAlServidor(conCodigoBarras codigoBarras: String) {
        // Concatenar el código de barras a la URL
        let urlString = "http://server/index.php/ExternalCalls/buscarCodigoBarras/\(codigoBarras)"
        
        // Crear una URL válida con la URL concatenada
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET" // Usar GET para buscar
            
            // Establecer el tipo de contenido como JSON (puede que no sea necesario)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Crear una tarea de URLSession para enviar la solicitud
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error al enviar la solicitud: \(error.localizedDescription)")
                    // Manejo de errores aquí
                    return
                }
                
                if let data = data {
                    let responseString = String(data: data, encoding: .utf8)
                    print("Respuesta del servidor: \(responseString ?? "No se pudo decodificar como UTF-8")")
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            // Verificar que el JSON tenga los campos necesarios antes de la decodificación
                            if let id = json["id"] as? String, let name_es = json["name_es"] as? String, let reference = json["reference"] as? String, let internalPackBarcode = json["internalPackBarcode"] as? String, let dun14 = json["dun14"] as? String {
                                let barCode = json["barCode"] as? String
                                let ean13 = json["ean13"] as? String
                                
                                respuestaDelServidor = Respuesta(id: id, name_es: name_es, reference: reference, barCode: barCode, internalPackBarcode: internalPackBarcode, dun14: dun14, ean13: ean13)
                            } else {
                                print("La respuesta JSON no contiene todos los campos necesarios.")
                            }
                        } else {
                            print("La respuesta no es un objeto JSON válido.")
                        }
                    } catch {
                        print("Error al decodificar la respuesta JSON: \(error.localizedDescription)")
                    }
                }
//                // Verificar el código de estado de la respuesta HTTP
//                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
//                    if let data = data {
//                        // Imprimir la respuesta del servidor para depuración
//                        let responseString = String(data: data, encoding: .utf8)
//                        print("Respuesta del servidor: \(responseString ?? "No se pudo decodificar como UTF-8")")
//
//                        do {
//                            // Decodificar la respuesta JSON en la variable 'respuestaDelServidor'
//                            respuestaDelServidor = try JSONDecoder().decode(Respuesta.self, from: data)
//                        } catch {
//                            print("Error al decodificar la respuesta JSON: \(error.localizedDescription)")
//                        }
//                    }
//
//
//                } else {
//                    print("Error: Código de estado de respuesta no válido")
//                    // Manejo de errores de código de estado no válido aquí
//                }
            }
            
            // Iniciar la tarea
            task.resume()
        }
    }


}



/*import SwiftUI
import CodeScanner

struct ContentView: View {
    @State private var scannedCode: String?
    
    var body: some View {
        VStack {
            if let code = scannedCode {
                Text("Código escaneado: \(code)")
            } else {
                CodeScannerView(codeTypes: [.code128, .code39, .ean8, .ean13], simulatedData: "pep") { response in
                    switch response {
                    case .success(let result):
                        print("Found code: \(result.string)")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    
}


struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

*/



