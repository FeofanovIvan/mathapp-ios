//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 03/04/25.
//

// Полный Swift-перевод Android-класса Keyboard.kt
// Аналог кастомной LaTeX-клавиатуры для iOS на Swift с WKWebView и логикой курсора

import SwiftUI
import WebKit

class MathKeyboardCoordinator: NSObject, ObservableObject {
    var webView: WKWebView?
    var left: [String] = []
    var right: [String] = []
    var onLatexUpdate: ((String) -> Void)?

    let symRoundBracket = ["\\sqrt(", "(", "log_{"]
    let symCurlyBracket = ["\\sqrt{", "^{", "\\frac{"]
    let symClosing = [")", "}", "}{", "}(", "]", "]{"]
    let symOpening = [
        "sin", "cos", "\\sqrt(", "(", "log_{", "\\sqrt{", "}{", "}(", "^{", "\\frac{",
        "tg", "ctg", "arcs", "arcc", "arct", "arcct", ""
    ]
    let symNumbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "y", "a", "b", "c", "x", "^\\circ", "\\cup"]
    let symArithmeticWoMinus = ["+", "*", "^{"]
    let symSigns = ["+", "-", "*", "^\\circ", "\\cup"]
    let symRootBracket = ["\\sqrt["]
    let symTrigFunctions = ["\\sin", "\\cos", "\\tan", "\\cot", "\\arcsin", "\\arccos", "\\arctan", "arccot"]


    func setWebView(_ view: WKWebView) {
        self.webView = view

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        view.configuration.defaultWebpagePreferences = preferences
    }

    func resetText() {
        left = []
        right = []
    }

    func delete() {
        guard !left.isEmpty else { return }

        let lastItem = left.removeLast()
        guard let lastChar = lastItem.last else { return }

        // Если это закрывающая скобка — не удаляем, а перемещаем в right
        if lastItem == "}{" || lastItem == "}(" || lastChar == "}" || lastChar == ")" {
            right.append(lastItem)

        // Если удаляется логарифм или дробь — убираем 2 элемента из right
        } else if lastItem == "\\frac{" || lastItem == "log_{" {
            if right.count >= 2 {
                right.removeLast()
                right.removeLast()
            }

        // Если удаляется открывающая скобка — убираем один элемент из right
        } else if lastChar == "{" || lastChar == "(" {
            if !right.isEmpty {
                right.removeLast()
            }
        }

        updateMathView()
    }


    func addSymbol(_ symbol: String) {
        print("⌨️ Нажата клавиша: \(symbol)")

        // Проверка ограничений на вставку
        if isInsertionViolations(symbol) {
            return
        }

        // Комбинация ">="
        if let last = left.last, last == ">", symbol == "=" {
            left[left.count - 1] = "\\geq "
        }
        // Комбинация "<="
        else if let last = left.last, last == "<", symbol == "=" {
            left[left.count - 1] = "\\leq "
        }
        // Вставка закрывающей скобки – берём из right
        else if symbol == "}" {
            if let fromRight = right.last {
                left.append(fromRight)
            }
        }
        // Обычное добавление
        else {
            left.append(symbol)
        }

        // Обработка скобок и вложенных выражений
        handleBrackets(symbol)
        handleBracketsS(symbol)

        // Обновляем WebView
        updateMathView()
    }


    func updateMathView() {
        let latex = getLatexText()
        print("📤 Формируем LaTeX: \(latex)")

        // Уведомляем SwiftUI, чтобы обновить превью формулы
        onLatexUpdate?(latex)
    }



    func getLatexText() -> String {
        let result = left.joined() + "\\lceil" + right.reversed().joined()
        print("\u{1F4E6} Финальный latexText: \(result)")
        return result
    }

    private func handleBrackets(_ symbol: String) {
        // Добавляем или удаляем соответствующие закрывающие скобки

        // Круглые скобки и логарифмы
        if symRoundBracket.contains(symbol) {
            right.append(")")
            if symbol == "log_{" {
                // Добавляем разделитель между основанием и аргументом логарифма
                right.append("}(")
            }

        // Фигурные скобки и дроби
        } else if symCurlyBracket.contains(symbol) {
            right.append("}")
            if symbol == "\\frac{" {
                // Добавляем разделитель между числителем и знаменателем
                right.append("}{")
            }

        // Удаление закрывающих скобок при ручном закрытии
        } else if symbol == ")" || symbol == "}" {
            if !right.isEmpty {
                right.removeLast()
            }
        }
        // Добавление круглых скобок после тригонометрических функций
            if symTrigFunctions.contains(symbol) {
                left.append("(")
                right.append(")")
            }
    }


    private func handleBracketsS(_ symbol: String) {
        // Обработка скобок для корня с основанием (например, √[3]{x})
        if symRootBracket.contains(symbol) {
            right.append("}")
            if symbol == "\\sqrt[" {
                // Разделитель между основанием и подкоренным выражением
                right.append("]{")
            }
        }
    }


    private func isInsertionViolations(_ symbol: String) -> Bool {
        let lastSymbol = left.last ?? ""
        let nextSymbol = right.last ?? ""

        print("🔍 Проверка вставки символа: \(symbol), последний символ: \(lastSymbol), следующий символ: \(nextSymbol)")

        if symOpening.contains(lastSymbol) && symArithmeticWoMinus.contains(symbol) && !symTrigFunctions.contains(lastSymbol) {
            print("⚠️ Нельзя вставить арифметический знак после открытия выражения")
            return true
        }

        if !symNumbers.contains(lastSymbol) && symbol == "." {
            print("⚠️ Десятичная точка может быть только после числа")
            return true
        }

        if lastSymbol == "." && !symNumbers.contains(symbol) {
            print("⚠️ Только число после десятичной точки")
            return true
        }

        if symSigns.contains(lastSymbol) && symSigns.contains(symbol) {
            print("⚠️ Избегаем двойных знаков")
            return true
        }

        if symSigns.contains(lastSymbol) && symbol == "^{" {
            print("⚠️ Возведение в степень после знака не допускается")
            return true
        }

        if lastSymbol == "}" && symbol == "^{" {
            print("⚠️ Возведение в степень после закрытия выражения")
            return true
        }

        if symOpening.contains(lastSymbol) && symClosing.contains(symbol) && !symTrigFunctions.contains(lastSymbol) {
            print("⚠️ Нет скобок без содержимого")
            return true
        }

        if symbol == ")" && nextSymbol != ")" {
            print("⚠️ Неправильное закрытие скобок в вложенных функциях")
            return true
        }

        if symbol == "}" && !symClosing.contains(nextSymbol) {
            print("⚠️ Неправильное закрытие фигурных скобок в вложенных функциях")
            return true
        }

        if symTrigFunctions.contains(lastSymbol) && symbol == "^{" {
            print("✅ Разрешаем возведение в степень после тригонометрической функции")
            return false
        }

        if lastSymbol == "\\pi" && symNumbers.contains(symbol) {
            print("✅ Добавляем умножение после символа π перед переменной")
            left.append("*")
            return false
        }

        return false
    }

    func handleButtonPress(id: String, value: String) {
        if id == "btX" {
            addSymbol("=")
        } else {
            switch id {
            case "bt_check", "CE":
                resetText()
            case "стереть", "bt_del":
                delete()
            case "bt_down":
                moveCursorRight()
            default:
                addSymbol(value)
            }
        }

        updateMathView()
    }

    func moveCursorRight() {
        guard !right.isEmpty else { return }

        let next = right.removeLast()
        left.append(next)
        updateMathView()
    }
    func clearLatexInput() {
        print("🧼 Очистка latex через clearLatexInput()")
        onLatexUpdate?("")
    }
    func clearAllInput() {
        print("🧼 Полная очистка ввода (как CE)")
        resetText()
        updateMathView()
    }


}

struct MathKeyboardView: UIViewRepresentable {
    let coordinator: MathKeyboardCoordinator
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        coordinator.setWebView(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> MathKeyboardCoordinator {
        return coordinator
    }
}
