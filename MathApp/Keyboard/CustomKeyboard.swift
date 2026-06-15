//
//  Untitled.swift
//  MathApp
//
//  Created by Ivan Feofanov on 03/04/25.
//

import SwiftUI

struct CustomKeyboard: View {
    let coordinator: MathKeyboardCoordinator
    var containerWidth: CGFloat = UIScreen.main.bounds.width

    let symbolMap: [String: String] = [
        "sin": "\\sin", "cos": "\\cos", "tg": "\\tan", "ctg": "\\cot",
        "asin": "\\arcsin", "acos": "\\arccos", "atg": "\\arctan", "actg": "arccot",
        "<": "<", "U": "\\cup ", ">": ">",
        "+": "+", "1": "1", "2": "2", "3": "3", "x": "x", "y": "y", "°": "^\\circ", "CE": "CE",
        "-": "-", "4": "4", "5": "5", "6": "6", "a": "a", "b": "b", "c": "c", "стереть": "стереть",
        "×": "*", "7": "7", "8": "8", "9": "9", "√": "\\sqrt[", "aⁿ": "^{", "log": "log_{", "e": "e",
        "\\": "\\frac{", ".": ".", "0": "0", "=": "=", "⏎": "ENTER", "(": "(", ")": ")", "π": "\\pi"
    ]

    var body: some View {
        VStack(spacing: 4) {
            keyboardRow(keys: ["sin", "cos", "tg", "ctg", "asin", "acos", "atg", "actg", "<", "U", ">"], numberOfButtons: 11)
            keyboardRow(keys: ["+", "1", "2", "3", "x", "y", "°", "CE"], numberOfButtons: 8)
            keyboardRow(keys: ["-", "4", "5", "6", "a", "b", "c", "стереть"], numberOfButtons: 8)
            keyboardRow(keys: ["×", "7", "8", "9", "√", "aⁿ", "log", "e"], numberOfButtons: 8)
            keyboardRow(keys: ["\\", ".", "0", "=", "⏎",  "(", ")", "π"], numberOfButtons: 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }

    private func keyboardRow(keys: [String], numberOfButtons: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                keyboardButton(key, width: flexibleWidth(for: numberOfButtons), isDelete: key == "стереть")
            }
        }
    }

    private func keyboardButton(
        _ title: String,
        width: CGFloat,
        isDelete: Bool = false,
        backgroundColor: Color = Color(red: 0.12, green: 0.18, blue: 0.35)
    ) -> some View {
        Button(action: {
            switch title {
            case "стереть":
                coordinator.handleButtonPress(id: "стереть", value: "стереть")
            case "CE":
                coordinator.handleButtonPress(id: "bt_check", value: "CE")
            case "⏎":
                coordinator.handleButtonPress(id: "bt_down", value: "⏎")
            default:
                if let symbol = symbolMap[title] {
                    coordinator.handleButtonPress(id: title, value: symbol)
                }
            }
        }) {
            if title == "стереть" {
                Image(systemName: "delete.left")
                    .font(.system(size: 16))
                    .frame(width: width, height: 40)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            } else {
                Text(title)
                    .font(.system(size: 14))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: width, height: 40)
                    .background(title == "⏎" ? Color.green : backgroundColor)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
        }
    }



    private func flexibleWidth(for numberOfButtons: Int) -> CGFloat {
            let totalSpacing = CGFloat(numberOfButtons - 1) * 4
            return (containerWidth - totalSpacing - 32) / CGFloat(numberOfButtons)
        }
    }

