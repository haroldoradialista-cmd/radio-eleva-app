# 📻 Rádio Eleva — Aplicativo Oficial

App Android da Rádio Eleva com player ao vivo, banners de promoções, chat entre ouvintes, notícias e pedido musical pelo WhatsApp. **Totalmente gerenciável pelo GitHub, sem precisar recompilar o app.**

---

## 🚀 Como colocar no ar (passo a passo)

### 1. Criar o repositório
1. Entre no GitHub e crie um repositório novo (ex.: `radio-eleva-app`), **público**.
2. Envie TODOS os arquivos e pastas deste projeto para o repositório (mantendo a estrutura de pastas).

### 2. Ajustar 1 arquivo de código (só uma vez)
Abra `lib/app_config.dart` e troque `SEU_USUARIO` e `SEU_REPOSITORIO` pelo seu usuário e nome do repositório. Exemplo:

```
https://raw.githubusercontent.com/haroldo/radio-eleva-app/main/config.json
```

### 3. Ajustar o config.json
Abra `config.json` e troque também os `SEU_USUARIO/SEU_REPOSITORIO` nos links das imagens, e coloque o número real do WhatsApp da rádio (formato: `5521XXXXXXXXX`).

### 4. Compilar o APK
1. No repositório, clique na aba **Actions**.
2. Clique em **Compilar APK da Rádio Eleva** → **Run workflow**.
3. Aguarde uns 10 minutos. Quando terminar, clique na execução e baixe o arquivo **radio-eleva-apk** na seção *Artifacts*.
4. Dentro do zip está o `app-release.apk` — instale no celular para testar!

---

## 🎛️ Como GERENCIAR o app (sem recompilar!)

Tudo o que o ouvinte vê é controlado pelo arquivo **`config.json`**. Você edita ele direto pelo navegador do GitHub (ícone de lápis ✏️), salva (*Commit changes*), e **na próxima vez que o ouvinte abrir o app, já aparece atualizado**. Não precisa gerar APK novo!

### Trocar banners de promoções/anunciantes
1. Envie a imagem do banner para a pasta `imagens/` do repositório (tamanho ideal: **1200 x 400 pixels**).
2. No `config.json`, ajuste a lista `banners`:
```json
"banners": [
  { "imagem": "https://raw.githubusercontent.com/SEU_USUARIO/radio-eleva-app/main/imagens/promocao_julho.png", "link": "https://instagram.com/radioeleva" }
]
```
O `link` é opcional — é para onde o ouvinte vai ao tocar no banner.

### Publicar notícias
Adicione itens na lista `noticias`. Se preencher `link`, abre o site; se preencher `texto`, abre a matéria dentro do app.

### Trocar WhatsApp, redes sociais, slogan ou streaming
Basta editar os campos correspondentes no `config.json`.

---

## 💬 Ativar o Chat dos ouvintes (opcional, grátis)

1. Acesse [console.firebase.google.com](https://console.firebase.google.com) e crie um projeto (ex.: `radio-eleva`).
2. No menu, vá em **Realtime Database** → *Criar banco de dados* → local `us-central1` → iniciar em **modo de teste**.
3. Na aba **Regras**, cole e publique:
```json
{
  "rules": {
    "chat": { ".read": true, ".write": true },
    "votos": { ".read": true, ".write": true }
  }
}
```
4. Copie a URL do banco (algo como `https://radio-eleva-default-rtdb.firebaseio.com`).
5. No `config.json`, preencha:
```json
"chat_url": "https://radio-eleva-default-rtdb.firebaseio.com/chat"
```
Pronto — o chat aparece automaticamente no app. Os votos de **gostei/não gostei** das músicas também ficam salvos nesse banco (nó `votos`), com o nome da música e a hora.

---

## 📁 Estrutura do projeto

| Arquivo/Pasta | O que é |
|---|---|
| `config.json` | **Painel de controle** — banners, notícias, WhatsApp, redes, chat |
| `imagens/` | Suas imagens de banners |
| `lib/` | Código do app (não precisa mexer) |
| `lib/app_config.dart` | Único código que você edita (URL do config) |
| `assets/logo.png` | Logo da rádio (vira o ícone do app) |
| `.github/workflows/build.yml` | Compilação automática do APK na nuvem |
| `setup_android.sh` | Preparação do Android (roda sozinho na nuvem) |

---

## 🎨 Visual

Paleta oficial derivada da logo: **azul profundo** (fundo), **verde e azul vivo** (player e destaques), **dourado** (detalhes e menu), **branco** (textos). Layout alinhado com margens consistentes de 14–28px.
