"""Gera o ícone do app (carrinho + símbolo da logo NEXTPDV) em todos os tamanhos.

Uso: python tool/gerar_icone.py [previa]
  previa  -> só grava tool/icone_previa.png com as variações lado a lado
  (sem)   -> grava os ícones do Android (legado e adaptativo) e da versão web
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(RAIZ, 'assets', 'images', 'nextpdv_logo_sem_fundo.png')

MARINHO_1 = (12, 35, 63)
MARINHO_2 = (7, 20, 38)
LARANJA = (255, 107, 0)
LARANJA_ESCURO = (234, 88, 12)
BRANCO = (255, 255, 255)
N = 1024  # tela de trabalho (depois reduz com antialias)


def eh_laranja(r, g, b):
    return r > 180 and 60 < g < 190 and b < 110 and r - b > 120


def simbolo():
    """Seta laranja e o restante do símbolo (aparelho + X), separados, sem o texto da logo."""
    im = Image.open(LOGO).convert('RGBA')
    im = im.crop((120, 0, 470, 285))  # parte de cima: só o símbolo
    seta = Image.new('RGBA', im.size, (0, 0, 0, 0))
    resto = Image.new('RGBA', im.size, (0, 0, 0, 0))
    ps, pr, pi = seta.load(), resto.load(), im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = pi[x, y]
            if a < 40:
                continue
            if eh_laranja(r, g, b):
                ps[x, y] = (r, g, b, a)
            elif r + g + b < 420:  # azul-marinho do aparelho e do X
                pr[x, y] = (r, g, b, a)
    seta, resto = limpar(seta), limpar(resto)
    return seta.crop(seta.getbbox()), resto.crop(resto.getbbox())


def limpar(camada):
    """Tira os pixels soltos da logo (ruído de compressão) e suaviza a borda."""
    alfa = camada.split()[3]
    alfa = alfa.filter(ImageFilter.MedianFilter(5)).point(lambda v: 255 if v > 110 else 0)
    alfa = alfa.filter(ImageFilter.GaussianBlur(0.8))
    cor = camada.copy()
    # cor uniforme da marca, sem a granulação da imagem original
    media = [0, 0, 0, 0]
    for r, g, b, a in camada.getdata():
        if a > 200:
            media[0] += r; media[1] += g; media[2] += b; media[3] += 1
    if media[3]:
        cor = Image.new('RGBA', camada.size, (media[0] // media[3], media[1] // media[3], media[2] // media[3], 255))
    cor.putalpha(alfa)
    return cor


def fundo_marinho(tam=N):
    fundo = Image.new('RGBA', (tam, tam))
    d = ImageDraw.Draw(fundo)
    for y in range(tam):
        t = y / tam
        cor = tuple(int(MARINHO_1[i] * (1 - t) + MARINHO_2[i] * t) for i in range(3))
        d.line([(0, y), (tam, y)], fill=cor + (255,))
    # brilho suave no alto, à esquerda
    brilho = Image.new('RGBA', (tam, tam), (0, 0, 0, 0))
    ImageDraw.Draw(brilho).ellipse((-tam * 0.3, -tam * 0.45, tam * 0.9, tam * 0.55), fill=(255, 255, 255, 28))
    return Image.alpha_composite(fundo, brilho.filter(ImageFilter.GaussianBlur(tam // 10)))


def carrinho(cor, escala=1.0, dx=0, dy=0):
    """Carrinho de traço grosso e cantos arredondados, desenhado numa camada transparente."""
    camada = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)

    def p(x, y):
        return (N / 2 + (x - 512) * escala + dx, N / 2 + (y - 512) * escala + dy)

    w = int(52 * escala)
    linha = [p(205, 330), p(300, 330), p(372, 640), p(735, 640)]
    d.line(linha, fill=cor, width=w, joint='curve')
    cesta = [p(325, 420), p(800, 420), p(752, 590), p(362, 590)]
    d.line(cesta + [cesta[0]], fill=cor, width=w, joint='curve')
    for x, y in [linha[0], linha[-1]] + cesta:
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=cor)
    for cx in (430, 690):
        x, y = p(cx, 735)
        r = 46 * escala
        d.ellipse((x - r, y - r, x + r, y + r), fill=cor)
    return camada


def colar(base, img, largura, centro):
    a = largura / img.size[0]
    img = img.resize((int(img.size[0] * a), int(img.size[1] * a)), Image.LANCZOS)
    base.alpha_composite(img, (int(centro[0] - img.size[0] / 2), int(centro[1] - img.size[1] / 2)))


def tingir(img, cor):
    alfa = img.split()[3]
    sol = Image.new('RGBA', img.size, cor + (255,))
    sol.putalpha(alfa)
    return sol


def sombra(camada, desloc=(0, 18), raio=22, opacidade=110):
    s = tingir(camada, (0, 0, 0))
    s.putalpha(s.split()[3].point(lambda v: v * opacidade // 255))
    s = s.filter(ImageFilter.GaussianBlur(raio))
    fundo = Image.new('RGBA', camada.size, (0, 0, 0, 0))
    fundo.alpha_composite(s, desloc)
    return fundo


def primeiro_plano(variante, escala=1.0):
    """Só o desenho (sem fundo), centrado, para o ícone adaptativo e para compor as variações."""
    seta, resto = simbolo()
    frente = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    if variante == 'A':
        # Carrinho branco e a seta laranja da logo saindo da cesta para cima.
        frente.alpha_composite(carrinho(BRANCO + (255,), 0.86 * escala, dx=-10 * escala, dy=40 * escala))
        colar(frente, seta, 560 * escala, (N / 2 + 40 * escala, N / 2 - 130 * escala))
    elif variante == 'B':
        # Carrinho laranja com o símbolo inteiro (aparelho + X em branco e seta laranja) dentro da cesta.
        frente.alpha_composite(carrinho(LARANJA + (255,), 0.9 * escala, dy=30 * escala))
        marca = Image.new('RGBA', resto.size, (0, 0, 0, 0))
        marca.alpha_composite(tingir(resto, BRANCO))
        colar(frente, marca, 250 * escala, (N / 2 + 40 * escala, N / 2 - 140 * escala))
        colar(frente, seta, 330 * escala, (N / 2 + 60 * escala, N / 2 - 150 * escala))
    else:
        # C: símbolo da logo grande com um carrinho branco pequeno no canto.
        marca = Image.new('RGBA', resto.size, (0, 0, 0, 0))
        marca.alpha_composite(tingir(resto, BRANCO))
        colar(frente, marca, 470 * escala, (N / 2 - 30 * escala, N / 2 - 10 * escala))
        colar(frente, seta, 600 * escala, (N / 2 + 10 * escala, N / 2 - 30 * escala))
        mini = carrinho(LARANJA + (255,), 0.42 * escala, dx=230 * escala, dy=250 * escala)
        frente.alpha_composite(mini)
    com_sombra = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    com_sombra.alpha_composite(sombra(frente))
    com_sombra.alpha_composite(frente)
    return com_sombra


def icone(variante, escala=1.0):
    base = fundo_marinho()
    base.alpha_composite(primeiro_plano(variante, escala))
    return base


def mascara_arredondada(img, raio=0.22):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), int(img.size[0] * raio), fill=255)
    saida = Image.new('RGBA', img.size, (0, 0, 0, 0))
    saida.paste(img, (0, 0), m)
    return saida


def previa():
    tela = Image.new('RGBA', (3 * 560 + 80, 760), (245, 247, 250, 255))
    d = ImageDraw.Draw(tela)
    for i, v in enumerate('ABC'):
        grande = mascara_arredondada(icone(v)).resize((480, 480), Image.LANCZOS)
        tela.alpha_composite(grande, (40 + i * 560, 40))
        # como fica pequeno, do tamanho da tela inicial do celular
        for j, t in enumerate((144, 96, 48)):
            peq = mascara_arredondada(icone(v)).resize((t, t), Image.LANCZOS)
            tela.alpha_composite(peq, (40 + i * 560 + j * 160, 560 + (144 - t) // 2))
        d.text((40 + i * 560, 715), 'Opcao ' + v, fill=(15, 23, 42, 255))
    destino = os.path.join(RAIZ, 'tool', 'icone_previa.png')
    tela.convert('RGB').save(destino)
    print(destino)


TAMANHOS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def gravar(variante):
    res = os.path.join(RAIZ, 'android', 'app', 'src', 'main', 'res')
    completo = icone(variante)
    # Ícone adaptativo (Android 8+): o desenho fica no centro de 108 dp; a zona segura é o círculo de 66 dp.
    frente_adapt = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    frente_adapt.alpha_composite(primeiro_plano(variante, escala=66 / 108 * 1.12))
    fundo_adapt = fundo_marinho()
    for pasta, f in TAMANHOS.items():
        d = os.path.join(res, 'mipmap-' + pasta)
        os.makedirs(d, exist_ok=True)
        completo.resize((int(48 * f), int(48 * f)), Image.LANCZOS).save(os.path.join(d, 'ic_launcher.png'))
        mascara_arredondada(completo, 0.5).resize((int(48 * f), int(48 * f)), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_round.png'))
        frente_adapt.resize((int(108 * f), int(108 * f)), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_foreground.png'))
        fundo_adapt.resize((int(108 * f), int(108 * f)), Image.LANCZOS).save(os.path.join(d, 'ic_launcher_background.png'))
    anydpi = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '</adaptive-icon>\n')
    for nome in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        open(os.path.join(anydpi, nome), 'w', encoding='utf-8').write(xml)
    web = os.path.join(RAIZ, 'web')
    completo.resize((192, 192), Image.LANCZOS).save(os.path.join(web, 'icons', 'Icon-192.png'))
    completo.resize((512, 512), Image.LANCZOS).save(os.path.join(web, 'icons', 'Icon-512.png'))
    completo.resize((192, 192), Image.LANCZOS).save(os.path.join(web, 'icons', 'Icon-maskable-192.png'))
    completo.resize((512, 512), Image.LANCZOS).save(os.path.join(web, 'icons', 'Icon-maskable-512.png'))
    mascara_arredondada(completo).resize((64, 64), Image.LANCZOS).save(os.path.join(web, 'favicon.png'))
    mascara_arredondada(completo).save(os.path.join(RAIZ, 'assets', 'images', 'icone_app.png'))
    print('ícones gravados, variação', variante)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'previa':
        previa()
    else:
        gravar(sys.argv[1] if len(sys.argv) > 1 else 'A')
