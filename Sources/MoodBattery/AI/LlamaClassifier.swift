//
//  LlamaClassifier.swift
//  Swing
//
//  Created by Mateusz Wojczynski on 27/10/2026.
//
import Foundation
import LLM

actor LlamaClassifier: EntryClassifier {
	private let llm: LLM
	
	init(modelURL: URL) throws {
		guard let llm = LLM(from: modelURL, template: .gemma4(TagPrompt.system), seed: 42, temp: 0.1, repeatPenalty: 1.0, maxTokenCount: 4096) else {
			throw ClassifierError.modelLoadFailed
		}
		self.llm = llm
	}
	
	func classify(title: String?, note: String?) async throws -> [MoodTag] {
		// getCompletion sends text to the model as-is, so wrap it in the Gemma 4 template (system prompt + turns) ourselves.
		let prompt = llm.preprocess(TagPrompt.user(title: title, note: note), [], .none)
		print("[LlamaClassifier] prompt: \(prompt)")
		// The schema becomes a grammar: llama.cpp masks out any token that can't continue valid JSON with allowed tags.
		let reply = try await llm.core.generateWithConstraints(from: prompt, jsonSchema: TagPrompt.schema)
		print("[LlamaClassifier] raw reply: [\(reply)]")
		let tags = TagPrompt.parse(reply)
		print("[LlamaClassifier] parsed tags: \(tags)")
		return tags
	}
	
	enum ClassifierError: Error { case modelLoadFailed }
}

extension Template {
	/// Gemma 4's turn format. LLM.swift's built-in `.gemma` is the older Gemma 2/3 one, which has no system turn.
	/// No `<bos>`: llama.cpp adds it when tokenising, because the model asks for it. Thinking stays off by
	/// leaving out the `<|think|>` marker.
	static func gemma4(_ systemPrompt: String) -> Template {
		Template(
			system: ("<|turn>system\n", "<turn|>\n"),
			user: ("<|turn>user\n", "<turn|>\n"),
			bot: ("<|turn>model\n", "<turn|>\n"),
			stopSequence: "<turn|>",
			systemPrompt: systemPrompt
		)
	}
}
