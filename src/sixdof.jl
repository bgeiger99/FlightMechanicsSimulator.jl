function f(time, X, XCG, controls)

    # C Assign state & control variables
    # C
    # C     X(1)  -> vt (ft/s)
    # C     X(2)  -> alpha (rad)
    # C     X(3)  -> beta (rad)
    # C     X(4)  -> phi (rad)
    # C     X(5)  -> theta (rad)
    # C     X(6)  -> psi (rad)
    # C     X(7)  -> P (rad/s)
    # C     X(8)  -> Q (rad/s)
    # C     X(9)  -> R (rad/s)
    # C     X(10) -> North (ft)
    # C     X(11) -> East (ft)
    # C     X(12) -> Altitude (ft)
    # C     X(13) -> Pow

    xd = Array{Float64}(undef, 13)
    outputs = Array{Float64}(undef, 7)

    THTL = controls[1]
    EL = controls[2]
    AIL = controls[3]
    RDR = controls[4]

    # Assign state & control variables
    VT = X[1]
    ALPHA = X[2] * RTOD
    BETA = X[3] * RTOD
    PHI = X[4]
    THETA = X[5]
    PSI = X[6]
    P = X[7]
    Q = X[8]
    R = X[9]
    ALT = X[12]
    POW = X[13]

    # Air data computer and engine model
    AMACH, QBAR = adc(VT, ALT)
    CPOW = tgear(THTL)
    xd[13] = pdot(POW, CPOW)
    T = thrust(POW, ALT, AMACH)

    # Look-up tables and component buildup
    CXT = CX(ALPHA, EL)
    CYT = CY(BETA, AIL, RDR)
    CZT = CZ(ALPHA, BETA, EL)

    DAIL = AIL / DA_MAX
    DRDR = RDR / DR_MAX

    CLT = CL(ALPHA, BETA) + DLDA(ALPHA, BETA) * DAIL + DLDR(ALPHA, BETA) * DRDR
    CMT = CM(ALPHA, EL)
    CNT = CN(ALPHA, BETA) + DNDA(ALPHA, BETA) * DAIL + DNDR(ALPHA, BETA) * DRDR

    # Add damping derivatives
    CBTA = cos(X[3])
    U = VT * cos(X[2]) * CBTA
    V = VT * sin(X[3])
    W = VT * sin(X[2]) * CBTA
    TVT = 0.5 / VT
    B2V = B * TVT
    CQ = CBAR * Q * TVT

    D = damp(ALPHA)
    CXT = CXT + CQ * D[1]
    CYT = CYT + B2V * (D[2] * R + D[3] * P)
    CZT = CZT + CQ * D[4]
    CLT = CLT + B2V * (D[5] * R + D[6] * P)
    CMT = CMT + CQ * D[7] + CZT * (XCGR - XCG)
    CNT = CNT + B2V * (D[8] * R + D[9] * P) - CYT * (XCGR - XCG) * CBAR / B

    # Get ready for state equations
    STH = sin(THETA)
    CTH = cos(THETA)
    SPH = sin(PHI)
    CPH = cos(PHI)
    SPSI = sin(PSI)
    CPSI = cos(PSI)

    QS = QBAR * S
    QSB = QS * B
    RMQS = QS / MASS
    GCTH = GD * CTH
    QSPH = Q * SPH
    AY = RMQS * CYT
    AZ = RMQS * CZT

    # Force equations
    UDOT = R * V - Q * W - GD * STH + (QS * CXT + T) / MASS
    VDOT = P * W - R * U + GCTH * SPH + AY
    WDOT = Q * U - P * V + GCTH * CPH + AZ
    DUM = (U * U + W * W)

    xd[1] = (U * UDOT + V * VDOT + W * WDOT) / VT
    xd[2] = (U * WDOT - W * UDOT) / DUM
    xd[3] = (VT * VDOT - V * xd[1]) * CBTA / DUM

    # Kinematics
    xd[4] = P + (STH / CTH) * (QSPH + R * CPH)
    xd[5] = Q * CPH - R * SPH
    xd[6] = (QSPH + R * CPH) / CTH

    # Moments
    ROLL = QSB * CLT
    PITCH = QS * CBAR * CMT
    YAW = QSB * CNT
    PQ = P * Q
    QR = Q * R
    QHX = Q * HX

    xd[7] = (XPQ * PQ - XQR * QR + AZZ * ROLL + AXZ * (YAW + QHX)) / GAM
    xd[8] = (YPR * P * R - AXZ * (P^2 - R^2) + PITCH - R * HX) / AYY
    xd[9] = (ZPQ * PQ - XPQ * QR + AXZ * ROLL + AXX * (YAW + QHX)) / GAM

    # Navigation
    T1 = SPH * CPSI
    T2 = CPH * STH
    T3 = SPH * SPSI
    S1 = CTH * CPSI
    S2 = CTH * SPSI
    S3 = T1 * STH - CPH * SPSI
    S4 = T3 * STH + CPH * CPSI
    S5 = SPH * CTH
    S6 = T2 * CPSI + T3
    S7 = T2 * SPSI - T1
    S8 = CPH * CTH

    xd[10] = U * S1 + V * S3 + W * S6  # North speed
    xd[11] = U * S2 + V * S4 + W * S7  # East speed
    xd[12] = U * STH - V * S5 - W * S8  # Vertical speed

    # Outputs
    AN = -AZ / GD
    ALAT = AY / GD
    AX = (QS * CXT + T) / GD  # <<-- ASM: Definition missing

    outputs[1] = AN
    outputs[2] = ALAT
    outputs[3] = AX
    outputs[4] = QBAR
    outputs[5] = AMACH
    outputs[6] = Q
    outputs[7] = ALPHA

    return xd, outputs

end
