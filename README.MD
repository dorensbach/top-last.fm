# Top Last.FM
Programa (shellscript) para facilitar a busca de posição no ranking de ouvintes por artistas no [Last.fm](https://www.last.fm/home)

* * *
_Não afiliado de nenhuma forma ao Last.fm._
* * *

*Inicio projeto: 11/05/2024*

Antes de rodar o script, criar um arquivo `.env` com as configurações.\
Um exemplo de configuração pode ser encontardo em `.env.example`
Opções de configuração:
- _user_: Nome de usuário no Last.fm. Obrigatório.
- _topArtists_: Quantidade de artistas para ler do perfil do usuário, em ordem  crescente de scrobbles. Máximo: 50. 0 para não pegar do perfil do usuário. Caso omitido, serão pego os 50 primeiros aristas.
- _extraArtists_: Array com artistas que deseja pesquisar a posição. Informar nomes no seguinte formato:
`["Hatefulmurder", "Héia", "Mentes Insanas", "Ode Insone", "Silent Cry"]`

Dependências:
- [jq](https://jqlang.github.io/jq/)
- [pup](https://github.com/ericchiang/pup)

### TODO
- Adicionar textos (boas vindas, etc)
