import Testing
@testable import SusurrameloCore

@Suite struct TranscriptAssemblerTests {
    @Test func keepsEveryCommittedSegmentInOrder() {
        var assembler = TranscriptAssembler()
        assembler.partial("Esta es")
        assembler.committed("Esta es una prueba.")
        assembler.partial("Segunda")
        assembler.committed("Segunda frase.")
        assembler.committed("Tercera frase.")
        #expect(assembler.committedText == "Esta es una prueba. Segunda frase. Tercera frase.")
    }

    @Test func skipsEmptySegmentsAndTrims() {
        var assembler = TranscriptAssembler()
        assembler.committed("  Hola. ")
        assembler.committed("   ")
        assembler.committed("Chau.")
        #expect(assembler.committedText == "Hola. Chau.")
    }

    @Test func bestEffortTextAppendsThePendingPartial() {
        var assembler = TranscriptAssembler()
        assembler.committed("Primera parte.")
        assembler.partial("y lo que faltaba")
        #expect(assembler.bestEffortText == "Primera parte. y lo que faltaba")
        assembler.committed("Y lo que faltaba.")
        #expect(assembler.bestEffortText == "Primera parte. Y lo que faltaba.")
    }

    @Test func emptyWhenNothingArrived() {
        let assembler = TranscriptAssembler()
        #expect(assembler.committedText.isEmpty)
        #expect(assembler.bestEffortText.isEmpty)
    }
}
