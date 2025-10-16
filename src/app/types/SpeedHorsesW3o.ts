
import {
    AntelopeTokensService,
    AntelopeResourcesService
} from "@vapaee/w3o-antelope";
import {
    EthereumTokensService
} from "@vapaee/w3o-ethereum";
import { SpeedHorsesService } from "@app/services/w3o/speed-horses.service";

export interface SpeedHorsesW3oServices {
    antelope: {
        tokens: AntelopeTokensService;
        resources: AntelopeResourcesService;
    };
    ethereum: {
        tokens: EthereumTokensService;
        speedhorses: SpeedHorsesService;
    };
    snapshot: () => any;
}
