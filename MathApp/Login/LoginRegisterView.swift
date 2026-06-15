//
//  LoginRegisterView.swift
//  MathApp
//
//  Created by Ivan Feofanov on 04/01/25.
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import FirebaseStorage
import CoreData
import FirebaseFirestore

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseCore


struct LoginView: View {
    @State private var isLogin: Bool = true
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var showPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentNonce: String?
    @State private var isAuthenticated = false

    @State private var appleCoordinator: AppleSignInCoordinator?
    @State private var applePresentationProvider: ApplePresentationAnchorProvider?
    @FocusState private var focusedField: ActiveField?
    @AppStorage("selectedProfile") private var selectedProfile: String = ""
    
    enum ActiveField {
        case name, email, password
    }

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.18, blue: 0.35)
                .ignoresSafeArea()

            if isAuthenticated || Auth.auth().currentUser != nil {
                // ⬇️ Если профиль ещё не выбран — показываем WelcomeBootstrapView,
                // иначе сразу уходим в MainView.
                if selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WelcomeBootstrapView()
                } else {
                    MainView()
                }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: { isLogin = true }) {
                            VStack {
                                Text("ВХОД")
                                    .font(.headline)
                                    .foregroundColor(isLogin ? .white : Color.gray.opacity(0.6))
                                Rectangle()
                                    .frame(height: 3)
                                    .foregroundColor(isLogin ? .white : .clear)
                            }
                        }.frame(maxWidth: .infinity)

                        Button(action: { isLogin = false }) {
                            VStack {
                                Text("РЕГИСТРАЦИЯ")
                                    .font(.headline)
                                    .foregroundColor(!isLogin ? .white : Color.gray.opacity(0.6))
                                Rectangle()
                                    .frame(height: 3)
                                    .foregroundColor(!isLogin ? .white : .clear)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 10)
                    Spacer(minLength: 60)


                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 20) {
                                if !isLogin {
                                    TextField("Введите имя", text: $name)
                                        .submitLabel(.next)
                                        .focused($focusedField, equals: .name)
                                        .onSubmit { focusedField = .email }
                                        .foregroundColor(.black)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focusedField == .name ? Color.green : Color.gray.opacity(0.5), lineWidth: 2))
                                }

                                TextField("Введите почту", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .email)
                                    .onSubmit { focusedField = .password }
                                    .foregroundColor(.black)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(focusedField == .email ? Color.green : Color.gray.opacity(0.5), lineWidth: 2))

                                HStack {
                                    Group {
                                        if showPassword {
                                            TextField("Введите пароль", text: $password)
                                        } else {
                                            SecureField("Введите пароль", text: $password)
                                        }
                                    }
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {  }
                                    .foregroundColor(.black)

                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(focusedField == .password ? Color.green : Color.gray.opacity(0.5), lineWidth: 2))

                                if isLogin {
                                    Button(action: {
                                        if email.isEmpty {
                                            alertMessage = "Введите почту для сброса пароля"
                                            showAlert = true
                                        } else {
                                            Auth.auth().sendPasswordReset(withEmail: email) { error in
                                                alertMessage = error?.localizedDescription ?? "Ссылка для сброса отправлена на почту"
                                                showAlert = true
                                            }
                                        }
                                    }) {
                                        Text("Забыли пароль?")
                                            .font(.footnote)
                                            .foregroundColor(.green)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.top, 5)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(radius: 5)
                            .padding(.horizontal)

                            Button(action: {
                                if email.isEmpty || password.isEmpty {
                                    alertMessage = "Пожалуйста, введите почту и пароль"
                                    showAlert = true
                                    return
                                }

                                if isLogin {
                                    Auth.auth().signIn(withEmail: email, password: password) { result, error in
                                        if let error = error {
                                            alertMessage = "Ошибка входа: \(error.localizedDescription)"
                                            showAlert = true
                                        } else {
                                            isAuthenticated = true
                                        }
                                    }
                                } else {
                                    Auth.auth().createUser(withEmail: email, password: password) { result, error in
                                        if let error = error {
                                            alertMessage = "Ошибка регистрации: \(error.localizedDescription)"
                                            showAlert = true
                                        } else if let user = result?.user {
                                            let db = Firestore.firestore()
                                            db.collection("users").document(user.uid).setData([
                                                "name": name,
                                                "email": email,
                                                "installSource": "AppStore",
                                                "createdAt": FieldValue.serverTimestamp()
                                            ])
                                            alertMessage = "Регистрация прошла успешно! Теперь войдите в аккаунт."
                                            showAlert = true
                                            isLogin = true
                                        }
                                    }
                                }
                            }) {
                                Text(isLogin ? "Войти" : "Зарегистрироваться")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 10) {
                                Text(isLogin ? "Войти с помощью:" : "Зарегистрироваться с помощью:")
                                    .foregroundColor(.white)
                                    .font(.footnote)

                                HStack(spacing: 20) {
                                    Button(action: {
                                        handleGoogleSignIn()
                                    }) {
                                        Image("google_logo")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .padding()
                                    }

                                    Button(action: {
                                        let nonce = randomNonceString()
                                        currentNonce = nonce

                                        let request = ASAuthorizationAppleIDProvider().createRequest()
                                        request.requestedScopes = [.email]
                                        request.nonce = sha256(nonce)

                                        let controller = ASAuthorizationController(authorizationRequests: [request])
                                        let coordinator = AppleSignInCoordinator(currentNonce: nonce) { result in
                                            switch result {
                                            case .success:
                                                isAuthenticated = true
                                            case .failure(let error):
                                                alertMessage = error.localizedDescription
                                                showAlert = true
                                            }
                                        }

                                        appleCoordinator = coordinator
                                        controller.delegate = coordinator
                                        let presentationProvider = ApplePresentationAnchorProvider()
                                        applePresentationProvider = presentationProvider
                                        controller.presentationContextProvider = presentationProvider

                                        controller.performRequests()
                                    }) {
                                        Image(systemName: "apple.logo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.white)
                                            .padding()
                                    }
                                }
                            }
                            .padding(.top, 20)

                            Spacer(minLength: 20)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Уведомление"), message: Text(alertMessage), dismissButton: .default(Text("ОК")))
                    }
                }
            }
        }
        .onAppear {
            if Auth.auth().currentUser != nil {
                isAuthenticated = true
            }
        }
    }
    private func handleGoogleSignIn() {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                alertMessage = "Не найден clientID Firebase"
                showAlert = true
                return
            }

            let config = GIDConfiguration(clientID: clientID)

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                alertMessage = "Не найден rootViewController"
                showAlert = true
                return
            }

            // Очистка предыдущего входа, чтобы Google показал окно авторизации
            GIDSignIn.sharedInstance.signOut()
            GIDSignIn.sharedInstance.configuration = config

            DispatchQueue.main.async {
                GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                    if let error = error {
                        alertMessage = "Ошибка Google входа: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }

                    guard let user = result?.user,
                          let idToken = user.idToken?.tokenString else {
                        alertMessage = "Не удалось получить токен Google"
                        showAlert = true
                        return
                    }

                    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

                    Auth.auth().signIn(with: credential) { authResult, error in
                        if let error = error {
                            alertMessage = "Ошибка Firebase входа: \(error.localizedDescription)"
                            showAlert = true
                        } else if let user = authResult?.user {
                            let db = Firestore.firestore()
                            db.collection("users").document(user.uid).setData([
                                "name": user.displayName ?? "",
                                "email": user.email ?? "",
                                "installSource": "GoogleSignIn",
                                "createdAt": FieldValue.serverTimestamp()
                            ], merge: true)
                            isAuthenticated = true
                        }
                    }
                }
            }
        }
    }


func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

func randomNonceString(length: Int = 32) -> String {
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        let randoms = (0 ..< 16).map { _ in UInt8.random(in: 0...255) }
        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}
class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    let currentNonce: String
    let completion: (Result<Void, Error>) -> Void

    init(currentNonce: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let identityToken = appleIDCredential.identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {

            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: tokenString,
                rawNonce: currentNonce,
                accessToken: nil
            )

            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    self.completion(.failure(error))
                    return
                }

                guard let user = Auth.auth().currentUser else {
                    self.completion(.failure(NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден после входа"])))
                    return
                }

                let db = Firestore.firestore()
                var userData: [String: Any] = [
                    "email": user.email ?? "",
                    "installSource": "AppleSignIn",
                    "createdAt": FieldValue.serverTimestamp()
                ]

                // Добавим имя, если оно передано (только при первой авторизации)
                if let fullName = appleIDCredential.fullName {
                    let displayName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")".trimmingCharacters(in: .whitespaces)
                    userData["name"] = displayName

                    // Обновим имя в FirebaseAuth профиле тоже (необязательно, но полезно)
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { _ in }
                }

                // Сохраняем или обновляем документ пользователя
                db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                    if let error = error {
                        print("🔥 Ошибка при сохранении данных Apple-пользователя: \(error.localizedDescription)")
                    } else {
                        print("✅ Данные Apple-пользователя сохранены")
                    }
                }

                self.completion(.success(()))
            }

        } else {
            self.completion(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Невозможно получить credential"])))
        }
    }


    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.completion(.failure(error))
    }
}

class ApplePresentationAnchorProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}




