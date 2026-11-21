package com.example.reviewlinkgenerator.nfc.inspector

import java.math.BigInteger

/**
 * Pure Kotlin ECDSA verifier over curve secp128r1 for NXP Originality Signatures (AN11350).
 */
object NxpSignatureVerifier {

    private val P = BigInteger("FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFF", 16)
    private val A = BigInteger("FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFC", 16)
    @Suppress("unused")
    private val B = BigInteger("E87579C11079F43DD824993C2CEE5ED3", 16)
    private val GX = BigInteger("161FF7528B899B2D0C28607CA52C5B86", 16)
    private val GY = BigInteger("CF5AC8395BAFEB13C02DA292DDED7A83", 16)
    private val N = BigInteger("FFFFFFFE0000000075A30D1B9038A115", 16)

    private val THREE = BigInteger.valueOf(3)
    private val TWO = BigInteger.valueOf(2)

    private data class EcPoint(val x: BigInteger?, val y: BigInteger?)

    private val INFINITY = EcPoint(null, null)
    private val G = EcPoint(GX, GY)

    private val NXP_PUBLIC_KEYS: List<EcPoint> = listOfNotNull(
        // NXP NTAG21x / NTAG I2C (2013)
        parseUncompressedPublicKey("04494E1A386D3D3CFE3DC10E5DE68A499B1C202DB5B132393E89ED19FE5BE8BC61"),
        // NXP MIFARE Ultralight EV1 (2013)
        parseUncompressedPublicKey("0490933BDCD6E99B4E255E3DA55389A827564E11718E017292FAF23226A96614B8")
    )

    private fun parseUncompressedPublicKey(hex: String): EcPoint? {
        if (hex.length != 66 || !hex.startsWith("04")) return null
        return try {
            val x = BigInteger(hex.substring(2, 34), 16)
            val y = BigInteger(hex.substring(34, 66), 16)
            EcPoint(x, y)
        } catch (_: Exception) {
            null
        }
    }

    private fun pointDouble(p: EcPoint): EcPoint {
        if (p == INFINITY || p.x == null || p.y == null || p.y == BigInteger.ZERO) {
            return INFINITY
        }
        val num = THREE.multiply(p.x.pow(2)).add(A).mod(P)
        val den = TWO.multiply(p.y).mod(P)
        if (den == BigInteger.ZERO) return INFINITY
        val lambda = num.multiply(den.modInverse(P)).mod(P)
        val x3 = lambda.pow(2).subtract(TWO.multiply(p.x)).mod(P)
        val y3 = lambda.multiply(p.x.subtract(x3)).subtract(p.y).mod(P)
        return EcPoint(x3, y3)
    }

    private fun pointAdd(p1: EcPoint, p2: EcPoint): EcPoint {
        if (p1 == INFINITY) return p2
        if (p2 == INFINITY) return p1
        val x1 = p1.x ?: return p2
        val y1 = p1.y ?: return p2
        val x2 = p2.x ?: return p1
        val y2 = p2.y ?: return p1

        if (x1 == x2) {
            return if (y1 == y2) pointDouble(p1) else INFINITY
        }

        val dx = x2.subtract(x1).mod(P)
        if (dx == BigInteger.ZERO) return INFINITY
        val lambda = y2.subtract(y1).mod(P).multiply(dx.modInverse(P)).mod(P)
        val x3 = lambda.pow(2).subtract(x1).subtract(x2).mod(P)
        val y3 = lambda.multiply(x1.subtract(x3)).subtract(y1).mod(P)
        return EcPoint(x3, y3)
    }

    private fun scalarMultiply(k: BigInteger, point: EcPoint): EcPoint {
        if (k <= BigInteger.ZERO || point == INFINITY) return INFINITY
        var result = INFINITY
        var addend = point
        var scalar = k
        while (scalar > BigInteger.ZERO) {
            if (scalar.testBit(0)) {
                result = pointAdd(result, addend)
            }
            addend = pointDouble(addend)
            scalar = scalar.shiftRight(1)
        }
        return result
    }

    fun verifyNxpOriginalitySignature(uid: ByteArray, signature: ByteArray): Boolean {
        if (uid.isEmpty() || signature.size != 32) return false
        return try {
            val r = BigInteger(1, signature.copyOfRange(0, 16))
            val s = BigInteger(1, signature.copyOfRange(16, 32))
            if (r <= BigInteger.ZERO || r >= N || s <= BigInteger.ZERO || s >= N) {
                return false
            }

            var z = BigInteger(1, uid)
            val uidBits = uid.size * 8
            val nBits = N.bitLength()
            if (uidBits > nBits) {
                z = z.shiftRight(uidBits - nBits)
            }

            val w = s.modInverse(N)
            val u1 = z.multiply(w).mod(N)
            val u2 = r.multiply(w).mod(N)

            val p1 = scalarMultiply(u1, G)
            for (publicKey in NXP_PUBLIC_KEYS) {
                val p2 = scalarMultiply(u2, publicKey)
                val point = pointAdd(p1, p2)
                if (point != INFINITY && point.x != null && point.x.mod(N) == r) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }
}
