// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package io.cylonix.tailchat

sealed class NetworkError : Exception() {
    object AddressNotFound : NetworkError()
    object DNSResolutionFailed : NetworkError()
    data class Unknown(override val cause: Throwable) : NetworkError()

    companion object {
        fun fromException(e: Exception): NetworkError {
            return when (e) {
                is NetworkError -> e
                else -> Unknown(e)
            }
        }
    }
}