#############################################################################
# JuMPeR
# Julia for Mathematical Programming - extension for Robust Optimization
# See http://github.com/IainNZ/JuMPeR.jl
#############################################################################

function printRobust(m::Model)
    rd = getRobust(m)
    # First, display normal model stuff
    print(m)
    println("Uncertain constraints:")
    for c in rd.uncertainconstr
        println(conToStr(c))
    end
    println("Uncertainty set:")
    for uc in rd.uncertaintyset
        println(conToStr(uc))
    end
    for unc in 1:rd.numUncs
        println("$(rd.uncLower[unc]) <= $(rd.uncNames[unc]) <= $(rd.uncUpper[unc])")
    end
end

#############################################################################
#############################################################################

function affToStr(a::UAffExpr, showConstant=true)
    const ZEROTOL = 1e-20

    if length(a.vars) == 0
        if showConstant
            return string_intclamp(a.constant)
        else
            return "0"
        end
    end

    # Get reference to robust part of model
    robdata = getRobust(a.vars[1].m)

    # Collect like terms
    indvec = IndexedVector(Float64, robdata.numUncs)
    for ind in 1:length(a.vars)
        addelt(indvec, a.vars[ind].unc, a.coeffs[ind])
    end

    # Stringify the terms
    elm = 0
    termStrings = Array(UTF8String, 2*length(a.vars))
    for i in 1:indvec.nnz
        idx = indvec.nzidx[i]
        if abs(abs(indvec.elts[idx])-1) <= ZEROTOL
            if elm == 0
                elm += 1
                if indvec.elts[idx] < 0
                    termStrings[1] = "-$(robdata.uncNames[idx])"
                else
                    termStrings[1] = "$(robdata.uncNames[idx])"
                end
            else 
                if indvec.elts[idx] < 0
                    termStrings[2*elm] = " - "
                else
                    termStrings[2*elm] = " + "
                end
                termStrings[2*elm+1] = "$(robdata.uncNames[idx])"
                elm += 1
            end
        elseif abs(indvec.elts[idx]) >= ZEROTOL
            if elm == 0
                elm += 1
                termStrings[1] = "$(string_intclamp(indvec.elts[idx])) $(robdata.uncNames[idx])"
            else 
                if indvec.elts[idx] < 0
                    termStrings[2*elm] = " - "
                else
                    termStrings[2*elm] = " + "
                end
                termStrings[2*elm+1] = "$(string_intclamp(abs(indvec.elts[idx]))) $(robdata.uncNames[idx])"
                elm += 1
            end
        end
    end
    

    if elm == 0
        ret = "0"
    else
        # And then connect them up with +s
        ret = join(termStrings[1:(2*elm-1)])
    end

    if abs(a.constant) >= 0.000001 && showConstant
        if a.constant < 0
            ret = string(ret, " - ", string_intclamp(abs(a.constant)))
        else
            ret = string(ret, " + ", string_intclamp(a.constant))
        end
    end
    return ret
end

#############################################################################
#############################################################################

function affToStr(a::FullAffExpr, showConstant=true)
    const ZEROTOL = 1e-20

    # If no variables, hand off to the constant part
    if length(a.vars) == 0
        return showConstant ? affToStr(a.constant) : "0"
    end

    # Get reference to robust part of model
    robdata = getRobust(a.vars[1].m)

    # Stringify the terms - we don't collect like terms
    termStrings = Array(UTF8String, length(a.vars))
    numTerms = 0
    first = true
    for i in 1:length(a.vars)
        numTerms += 1
        uaff = a.coeffs[i]
        varn = getName(a.vars[i])
        prefix = first ? "" : " + "
        # Coefficient expression is a constant
        if length(uaff.vars) == 0
            if abs(uaff.constant) <= ZEROTOL
                # Constant 0 - do not display this term at all
                termStrings[numTerms] = ""
            elseif abs(uaff.constant - 1) <= ZEROTOL
                # Constant +1
                termStrings[numTerms] = first ? varn : " + $varn"
            elseif abs(uaff.constant + 1) <= ZEROTOL
                # Constant -1
                termStrings[numTerms] = first ? "-$varn" : " - $varn"
            else
                # Constant is other than 0, +1, -1 
                if first
                    sign = uaff.constant < 0 ? "-" : ""
                    termStrings[numTerms] = "$sign$(string_intclamp(abs(uaff.constant))) $varn"
                else
                    sign = uaff.constant < 0 ? "-" : "+"
                    termStrings[numTerms] = " $sign $(string_intclamp(abs(uaff.constant))) $varn"
                end
            end
        # Coefficient expression is a single uncertainty
        elseif length(uaff.vars) == 1
            if abs(uaff.constant) <= ZEROTOL && abs(abs(uaff.coeffs[1]) - 1) <= ZEROTOL
                # No constant, so no (...) needed
                termStrings[numTerms] = string(prefix,affToStr(uaff)," ",varn)
            else
                # Constant - need (...)
                termStrings[numTerms] = string(prefix,"(",affToStr(uaff),") ",varn)
            end
        # Coefficient is a more complicated expression
        else
            termStrings[numTerms] = string(prefix,"(",affToStr(uaff),") ",varn)
        end
        first = false
    end

    # And then connect them up with +s
    ret = join(termStrings[1:numTerms], "")
    
    if showConstant
        con_aff = affToStr(a.constant)
        if con_aff != "" && con_aff != "0"
            ret = string(ret," + ",affToStr(a.constant))
        end
    end
    return ret
end