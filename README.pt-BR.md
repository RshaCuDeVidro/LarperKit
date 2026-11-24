<div align="center">

# LarperKit

**A base comum dos meus apps nativos: temas, componentes, plugins e traduções, escritos uma vez só.**

Zig 0.17 · SDL3 · Dear ImGui · KDL · Lua 5.4

[English](README.md) · **Português**

</div>

> [!NOTE]
> Bem no começo: nada veio pra cá ainda. O código ainda mora no [larperCord](https://github.com/RshaCuDeVidro/larperCord) e no larperNotes, e vem uma parte de cada vez (veja o [Roteiro](#roteiro)). É um kit para os meus próprios programas, então a API muda sempre que um deles precisar.

## Por quê

O larperCord e o larperNotes são feitos do mesmo jeito. O SDL3 abre a janela, e o Dear ImGui cuida do teclado e do mouse, das fontes e das caixas de texto. Cada app desenha a própria interface por cima, com o visual vindo de um arquivo de tema KDL.

O larperNotes começou de uma cópia da base do larperCord, e as duas cópias foram se afastando. O motor de temas do Notes tem 2.400 linhas, e o do larperCord tem 8.100: falta no Notes o esquema, as partes, o servidor de linguagem, as formas vetoriais e o papel de parede. Cada correção precisa ser levada de um para o outro na mão, e a maioria nunca é.

O LarperKit guarda essa base num lugar só. Um app importa o kit e ganha temas, componentes e plugins. O app só escreve o que é dele: as telas, os componentes que os temas dele podem estilizar e o que os plugins dele podem fazer.

## O que entra

- **Temas.** Arquivos de tema KDL descritos por um esquema só. Esse esquema confere o tema ao carregar (avisos com linha e coluna, e sugestão para erro de digitação) e alimenta o `--theme-check` e um servidor de linguagem para editores. Os temas ganham `extends` e `vars`, partes com estados (`part "button:hover"`), formas vetoriais, fundos procedurais e papel de parede local. Cada app registra os próprios componentes no esquema.
- **Componentes.** Botão, botão de ícone, interruptor, slider, seletor segmentado, menu suspenso, dica, aviso, janela de diálogo, menu, área de rolagem e caixa de texto.
  - Cada um pega o visual do tema, segue o fator de escala único da interface e funciona da direita para a esquerda.
  - Cada um ganha o identificador a partir de um nome (`id("save", i)`), e não de um número escolhido na mão, no estilo do [WooferSoundPad](https://github.com/RshaCuDeVidro/WooferSoundPad).
  - Cada um se registra no Inspetor e deixa uma marca para os testes visuais, então uma tela nova já nasce testável.
- **Parado por padrão.** Nada é desenhado enquanto nada muda, e uma animação só pede quadros enquanto se mexe.
- **Plugins.** O runtime de Lua 5.4: a sandbox, os manifestos, as permissões, o HTTP com regras por host, os segredos no chaveiro do sistema, os textos traduzidos e o painel dos plugins. O app decide quais funções os plugins dele recebem.
- **Traduções.** Os idiomas vêm de arquivos `.kdl`, com formas de plural, recarga na hora e quanto cada idioma traduz.
- **Texto.** Fontes que buscam no sistema a escrita que faltar, e o Dear ImGui modificado (texto da direita para a esquerda, métodos de entrada e as mudanças nas fontes) em que os dois apps se apoiam.
- **Vitrine.** Um app pequeno que desenha cada componente em cada tema: claro e escuro, em outras escalas e da direita para a esquerda. Ele é a demonstração e o alvo dos testes visuais ao mesmo tempo, então o kit se testa sozinho, sem abrir um app.

## API planejada

Um rascunho de para onde isso vai. Nada disso compila ainda.

```zig
const lk = @import("larperkit");

fn settingsPage(ui: *lk.Ui, s: *Settings) void {
    if (ui.button(lk.id("save", 0), "Save", .{ .kind = .primary })) s.save();
    ui.toggle(lk.id("compact", 0), "Compact mode", &s.compact);
    for (s.accounts, 0..) |_, i| {
        if (ui.iconButton(lk.id("remove-account", i), .trash, .{ .kind = .danger })) s.remove(i);
    }
}
```

Os mesmos componentes num tema:

```kdl
parts {
    part "button:hover" bg="@accent" radius=6
    part "toggle.knob:on" color="@accent"
}
```

## Roteiro

- [ ] **Base:** o motor de temas, os identificadores, as animações, o desenho e as traduções, tirados do código atual do larperCord.
- [ ] **larperNotes** passa a usar a base e larga as cópias dele.
- [ ] **Componentes** e a vitrine.
- [ ] **Runtime de plugins.**
- [ ] **Fontes** e o Dear ImGui modificado.
- [ ] **larperCord** passa a usar o kit, um módulo por vez, depois que a 0.7 sair.

## Licença

GPL-3.0, a mesma do larperCord, já que a maior parte do código vem de lá.
