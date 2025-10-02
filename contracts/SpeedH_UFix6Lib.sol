// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    UFix6: unsigned fixed-point with 6 decimals (scale = 1e6).
    - x real = X_ufix6 / 1e6
    - log2(x) implementado con método binario: log2(x) = n + frac, con x ∈ [1, 2) para la parte fraccionaria.
*/

type UFix6 is uint256;

/**
 * Título: SpeedH_UFix6Lib
 * Brief: Biblioteca matemática que implementa aritmética de punto fijo con seis decimales y utilidades logarítmicas necesarias para calcular niveles y escalados dentro del sistema de estadísticas de caballos. Centraliza las operaciones seguras para transformar valores enteros en representaciones fraccionarias sin perder precisión en cálculos recurrentes.
 * API: expone constructores (`fromUint`, `wrapRaw`, `fromParts`), conversores (`toUint`, `raw`), operaciones básicas (`add`, `sub`, `mul`, `mulUint`, `div`, `divUint`), constantes (`one`) y funciones logarítmicas (`ilog2`, `log2_uint`, `log2`). Estas rutinas son utilizadas por contratos como `SpeedH_Stats_Horse` para determinar niveles y tiempos de descanso dentro de los procesos de progresión del juego.
 */
library SpeedH_UFix6Lib {
    uint256 internal constant SCALE = 1e6;
    uint256 internal constant TWO_SCALE = 2 * SCALE;

    // ----- Constructors / converters -----
    function fromUint(uint256 x) internal pure returns (UFix6) {
        unchecked { return UFix6.wrap(x * SCALE); }
    }

    function toUint(UFix6 x) internal pure returns (uint256) {
        return UFix6.unwrap(x) / SCALE; // truncates decimals
    }

    function wrapRaw(uint256 xScaled) internal pure returns (UFix6) {
        // xScaled already in 1e6 scale
        return UFix6.wrap(xScaled);
    }

    function raw(UFix6 x) internal pure returns (uint256) {
        return UFix6.unwrap(x);
    }

    // ----- Basic arithmetic (all scaled) -----
    function add(UFix6 a, UFix6 b) internal pure returns (UFix6) {
        return UFix6.wrap(UFix6.unwrap(a) + UFix6.unwrap(b));
    }

    function sub(UFix6 a, UFix6 b) internal pure returns (UFix6) {
        return UFix6.wrap(UFix6.unwrap(a) - UFix6.unwrap(b));
    }

    function mul(UFix6 a, UFix6 b) internal pure returns (UFix6) {
        // (a*b)/SCALE, cuidado con overflow si a y b son enormes (no es tu caso).
        uint256 A = UFix6.unwrap(a);
        uint256 B = UFix6.unwrap(b);
        return UFix6.wrap((A * B) / SCALE);
    }

    function mulUint(UFix6 a, uint256 k) internal pure returns (UFix6) {
        return UFix6.wrap(UFix6.unwrap(a) * k);
    }

    function div(UFix6 a, UFix6 b) internal pure returns (UFix6) {
        uint256 A = UFix6.unwrap(a);
        uint256 B = UFix6.unwrap(b);
        return UFix6.wrap((A * SCALE) / B);
    }

    function divUint(UFix6 a, uint256 k) internal pure returns (UFix6) {
        return UFix6.wrap(UFix6.unwrap(a) / k);
    }

    // ----- Helpers -----
    function one() internal pure returns (UFix6) {
        return UFix6.wrap(SCALE);
    }

    function fromParts(uint256 integer, uint256 micro) internal pure returns (UFix6) {
        // micro is the 6-decimal fractional part, 0..999_999
        require(micro < SCALE, 'fraction too large');
        return UFix6.wrap(integer * SCALE + micro);
    }

    // ----- Integer log2 floor for uint256 (no scaling) -----
    function ilog2(uint256 x) internal pure returns (uint256 n) {
        // requires x > 0
        require(x > 0, 'log2(0) undefined');
        uint256 y = x;
        if (y >= 2**128) { y >>= 128; n += 128; }
        if (y >= 2**64)  { y >>= 64;  n += 64; }
        if (y >= 2**32)  { y >>= 32;  n += 32; }
        if (y >= 2**16)  { y >>= 16;  n += 16; }
        if (y >= 2**8)   { y >>= 8;   n += 8; }
        if (y >= 2**4)   { y >>= 4;   n += 4; }
        if (y >= 2**2)   { y >>= 2;   n += 2; }
        if (y >= 2**1)   { /* y >>= 1;*/ n += 1; }
    }

    // ----- log2(x) with x as uint in [1..1e18], returns UFix6 -----
    // Method: normalize x = 2^n * m, m in [1,2). Compute frac via iterative squaring on fixed-point.
    function log2_uint(uint256 x) internal pure returns (UFix6) {
        require(x > 0, 'log2(0) undefined');

        // n = floor(log2(x))
        uint256 n = ilog2(x);

        // mScaled = m * 1e6, where m = x / 2^n in [1,2)
        // Because x <= ~1e3 in your use case, (x * 1e6) fits safely.
        uint256 mScaled = (x * SCALE) >> n; // exact division by power of two

        // Fractional part via N iterations. N=20 gives ~1e-6 precision.
        uint256 fracScaled = 0;
        uint256 _add = SCALE >> 1; // SCALE/2
        for (uint256 i = 0; i < 20; i++) {
            // m = m^2
            // mScaled := (mScaled * mScaled) / SCALE, stays roughly in [1e6, 4e6)
            mScaled = (mScaled * mScaled) / SCALE;

            if (mScaled >= TWO_SCALE) {
                // if m >= 2, divide by 2 and set this fractional bit
                mScaled = mScaled / 2;
                fracScaled += _add;
            }
            _add >>= 1; // next bit weight: SCALE / 2^(i+2)
            if (_add == 0) { break; }
        }

        // total = n + frac (both in 1e6 scale)
        uint256 totalScaled = n * SCALE + fracScaled;
        return UFix6.wrap(totalScaled);
    }

    // log2(x) where x is already UFix6 (scaled), returns UFix6
    function log2(UFix6 x) internal pure returns (UFix6) {
        uint256 xScaled = UFix6.unwrap(x);
        require(xScaled > 0, 'log2(0) undefined');

        // Convert to integer domain by extracting integer part and remainder:
        // x_real = xScaled / SCALE. We want log2(x_real).
        // Handle it as log2(x_int + frac) ≈ log2(uint) + log2(1 + frac/uint)
        // Simpler: compute integer x_real first, but to keep it cheap we reuse log2_uint on an integer proxy:
        //   log2(x_real) = log2( xScaled / SCALE ) = log2(xScaled) - log2(SCALE)
        UFix6 lNum = log2_uint(xScaled);
        UFix6 lDen = log2_uint(SCALE);
        // subtraction in fixed domain
        return sub(lNum, lDen);
    }
}

/*
library LogMath {
    using SpeedH_UFix6Lib for UFix6;

    // result = K * log2(x), with x as uint (1..1000), returns UFix6
    function kMulLog2_uint(uint256 K, uint256 x) internal pure returns (UFix6) {
        UFix6 lx = SpeedH_UFix6Lib.log2_uint(x);         // UFix6
        return lx.mulUint(K);                      // still UFix6
    }

    // result = K * log2(x), with x as UFix6, returns UFix6
    function kMulLog2_ufix(uint256 K, UFix6 x) internal pure returns (UFix6) {
        UFix6 lx = SpeedH_UFix6Lib.log2(x);
        return lx.mulUint(K);
    }
}

// ---------- Example usage ----------

contract LogExample {
    using SpeedH_UFix6Lib for UFix6;

    uint256 public constant K = 100;

    function resultFor(uint256 x) external pure returns (uint256 resultScaled, uint256 resultInteger) {
        // x is plain integer in [1..1000]
        UFix6 r = LogMath.kMulLog2_uint(K, x);      // UFix6 (scale 1e6)
        resultScaled = SpeedH_UFix6Lib.raw(r);             // scaled by 1e6
        resultInteger = r.toUint();                 // truncated integer part
    }
    function resultForUFix6(UFix6 x) external pure returns (uint256 resultScaled, uint256 resultInteger) {
        // x is UFix6 (scale 1e6)
        UFix6 r = LogMath.kMulLog2_ufix(K, x);      // UFix6 (scale 1e6)
        resultScaled = SpeedH_UFix6Lib.raw(r);             // scaled by 1e6
        resultInteger = r.toUint();                 // truncated integer part
    }
}
*/
