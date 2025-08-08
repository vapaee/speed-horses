# TODO LIST
-----------
+ Verificar comoes el formato esperable para un ERC721 de manera tal que sus propiedades sean listadas en la TelosWallet
-> la función tokenURI(id)
--> retorna una URL:
  Wallet: http://localhost:8081/evm/collectible-details?contract=0xB8a0d67Ecc01E0ADee394a1FD95F87D96A9680a2&id=3379&tab=attributes
  Metadata: https://www.tekika.io/api/nft/get-nft?season=2&tokenId=3379



---------------
# SpeedHorses
Simple implementación de un NFT (ERC721) con ciertas particularidades

### Cracterísticas:
- Quien deploya el contrato será recordado como el admin (address)
- Sólo el admin podrá setear la addres del contrato HorseMinter y HorseStats
- El proceso de minteo sólo lo puede realizar el contrato HorseMinter y los parámetros son:
  - to: address
  - id: number

----------------
# HorseStats
- El caballo además de tener su ID único, tendrá asociada una pareja inmutable de propiedades: color, versión
- La url de la imagen tendrá un formato: "parte-1" + color + "parte-2" + versión + "parte-3"

----------------
# HorseMinter
